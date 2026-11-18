#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn unknown_tool_is_rejected() {
        assert!(tool("curl | sh").is_none());
        assert!(tool("codex").is_some());
        assert!(tool("vscode").is_some());
    }
    #[test]
    fn archive_rejects_traversal_and_absolute_paths() {
        assert!(safe_archive("VSCode-linux-arm64/bin/code\nVSCode-linux-arm64/code\n"));
        for entry in ["/etc/passwd", "VSCode-linux-arm64/../../etc/passwd", "other-root/file", ""] {
            assert!(!safe_archive(entry), "accepted {entry:?}");
        }
    }
    #[test]
    fn first_login_state_is_per_user_and_skip_persists() {
        let p=std::env::temp_dir().join(format!("pi-ai-test-{}",std::process::id()));
        let _=std::fs::remove_dir_all(&p);
        assert!(should_autostart(&p));
        dismiss(&p).unwrap();
        assert!(!should_autostart(&p));
        assert!(should_autostart(&p.join("other-user")));
        std::fs::remove_dir_all(p).unwrap();
    }
    #[test]
    fn vscode_launcher_uses_wayland_and_limits_software_fallback_to_vms() {
        let native=vscode_launcher(false);
        let vm=vscode_launcher(true);
        assert!(native.contains("--ozone-platform=wayland"));
        assert!(!native.contains("--disable-gpu"));
        assert!(vm.contains("--disable-gpu"));
        assert!(vm.contains("\"$@\""));
    }
    #[test]
    fn store_filters_distinguish_native_apps_from_terminal_tools() {
        assert!(catalog_matches(tool("claude").unwrap(), "Terminal", "anthropic"));
        assert!(!catalog_matches(tool("claude").unwrap(), "Desktop", ""));
        assert!(catalog_matches(tool("chatgpt-desktop").unwrap(), "Desktop", "codex"));
    }
    #[test]
    fn installer_permissions_are_scoped_to_the_selected_publisher_package() {
        let cmd=npm_command(Path::new("/tmp/my home"),tool("claude").unwrap());
        let args:Vec<_>=cmd.get_args().map(|s|s.to_string_lossy().into_owned()).collect();
        assert!(args.contains(&"--allow-scripts=@anthropic-ai/claude-code".to_owned()));
        assert!(!args.iter().any(|a|a=="--allow-scripts=true"));
        assert!(args.contains(&"/tmp/my home/.local".to_owned()));
    }
    #[test]
    fn errors_keep_the_useful_cause_without_terminal_escape_codes() {
        assert_eq!(error_summary("progress\n\x1b[31mnpm error code EACCES\x1b[0m\n\n"),"npm error code EACCES");
        assert_eq!(error_summary(""),"No additional diagnostic output.");
    }
    #[test]
    fn retry_errors_do_not_reuse_an_older_attempts_failure() {
        let log="\n=== old attempt ===\nnpm error code EACCES\n\n=== new attempt ===\ncurl: (23) Failure writing output to destination\n";
        assert_eq!(error_summary(log),"curl: (23) Failure writing output to destination");
    }
    #[test]
    fn a_silent_launch_retry_does_not_show_an_older_failure_or_its_marker() {
        let log="\n=== first launch ===\nEGL error: display unavailable\n\n=== second launch ===\n";
        assert_eq!(error_summary(log),"No additional diagnostic output.");
    }
    #[test]
    fn desktop_signin_handlers_never_take_over_web_browsing() {
        assert!(private_schemes("chatgpt-desktop").contains(&"x-scheme-handler/codex"));
        assert!(private_schemes("claude-desktop").contains(&"x-scheme-handler/claude"));
        assert!(private_schemes("grok-desktop").contains(&"x-scheme-handler/grokbot"));
        for id in ["chatgpt-desktop","claude-desktop","grok-desktop","vscode"] {
            assert!(!private_schemes(id).iter().any(|s|["x-scheme-handler/http","x-scheme-handler/https","x-scheme-handler/file"].contains(s)));
        }
    }
}
use std::{fs::{self, File, OpenOptions}, io::{self,Write}, path::{Component, Path, PathBuf}, process::{Command, Stdio}, thread, time::{Duration, Instant,SystemTime,UNIX_EPOCH}};
use std::os::unix::fs::PermissionsExt;

pub struct Tool { pub id: &'static str, pub name: &'static str, pub package: Option<&'static str>, pub binary: &'static str }
pub const TOOLS: [Tool; 7] = [
    Tool{id:"codex",name:"Codex · ChatGPT",package:Some("@openai/codex@latest"),binary:"codex"},
    Tool{id:"claude",name:"Claude Code",package:Some("@anthropic-ai/claude-code@latest"),binary:"claude"},
    Tool{id:"grok",name:"Grok Build",package:Some("@xai-official/grok@latest"),binary:"grok"},
    Tool{id:"vscode",name:"Visual Studio Code",package:None,binary:"code"},
    Tool{id:"chatgpt-desktop",name:"ChatGPT + Codex",package:None,binary:"chatgpt-desktop"},
    Tool{id:"claude-desktop",name:"Claude Desktop",package:None,binary:"claude-desktop"},
    Tool{id:"grok-desktop",name:"Grok Bot",package:None,binary:"grok-desktop"},
];
pub fn tool(id: &str) -> Option<&'static Tool> { TOOLS.iter().find(|t|t.id==id) }
pub struct Info {pub publisher:&'static str,pub description:&'static str,pub initials:&'static str,pub style:&'static str}
pub fn info(t:&Tool)->Info {
    match t.id {
        "codex"=>Info{publisher:"OpenAI",description:"Work with Codex in your terminal. Read, edit, and test code in your projects.",initials:"C",style:"openai"},
        "claude"=>Info{publisher:"Anthropic",description:"Bring Claude Code to the terminal for coding, debugging, and project work.",initials:"A",style:"anthropic"},
        "grok"=>Info{publisher:"xAI",description:"Use Grok Build from the terminal for interactive coding and development.",initials:"G",style:"xai"},
        "vscode"=>Info{publisher:"Microsoft",description:"A complete code editor with extensions, source control, and an integrated terminal.",initials:"<>",style:"vscode"},
        "chatgpt-desktop"=>Info{publisher:"OpenAI",description:"ChatGPT and the Codex desktop experience. Official Linux preview; experimental on LFS.",initials:"C",style:"openai"},
        "claude-desktop"=>Info{publisher:"Anthropic",description:"Chat and Claude Code in a desktop app. Official Linux beta; Cowork needs extra VM support.",initials:"A",style:"anthropic"},
        _=>Info{publisher:"xAI",description:"The official Grok Bot desktop client for chatting with and reviewing work from your Bots.",initials:"G",style:"xai"},
    }
}
pub fn category(t:&Tool)->&'static str {if t.package.is_some(){"Terminal"}else{"Desktop"}}
pub fn catalog_matches(t:&Tool,filter:&str,query:&str)->bool {
    (filter=="All" || filter==category(t)) && format!("{} {} {}",t.name,info(t).publisher,info(t).description).to_lowercase().contains(&query.to_lowercase())
}
pub fn private_schemes(id:&str)->&'static [&'static str] {
    match id {
        "chatgpt-desktop"=>&["x-scheme-handler/codex"],
        "claude-desktop"=>&["x-scheme-handler/claude"],
        "grok-desktop"=>&["x-scheme-handler/grokbot","x-scheme-handler/sand"],
        "vscode"=>&["x-scheme-handler/vscode"],
        _=>&[],
    }
}
pub(crate) fn register_desktop(apps:&Path,filename:&str,id:&str,log:&File)->Result<(),String> {
    run(Command::new("/usr/bin/update-desktop-database").arg(apps),log)?;
    for scheme in private_schemes(id) {
        let current=Command::new("/usr/bin/xdg-mime").args(["query","default",scheme]).output().map_err(|e|e.to_string())?;
        let current=String::from_utf8_lossy(&current.stdout);
        if current.trim().is_empty() || current.trim()==filename {
            run(Command::new("/usr/bin/xdg-mime").args(["default",filename,scheme]),log)?;
        }
    }
    Ok(())
}
pub fn error_summary(text:&str)->String {
    let text=if let Some((_,attempt))=text.rsplit_once("\n=== ") {
        attempt.split_once('\n').map(|(_,body)|body).unwrap_or("")
    } else {text};
    let mut clean=String::new();let mut escape=false;
    for ch in text.chars(){if ch=='\x1b'{escape=true;continue;}if escape{if ch.is_ascii_alphabetic(){escape=false;}continue;}if !ch.is_control() || ch=='\n' || ch=='\r'{clean.push(if ch=='\r'{'\n'}else{ch});}}
    let lines:Vec<_>=clean.lines().map(str::trim).filter(|s|!s.is_empty()).collect();
    lines.iter().rev().find(|s|{let s=s.to_lowercase();["error","failed","failure","denied","not found","could not","eacces","refused","no space"].iter().any(|key|s.contains(key))}).or_else(||lines.last()).map(|s|s.chars().take(240).collect()).unwrap_or_else(||"No additional diagnostic output.".into())
}
pub fn npm_command(home:&Path,t:&Tool)->Command {
    let mut cmd=Command::new("/usr/bin/npm");
    cmd.args(["install","--global","--no-audit","--no-fund","--fetch-retries=2","--fetch-timeout=60000","--registry=https://registry.npmjs.org"]);
    if t.id=="claude"{cmd.arg("--allow-scripts=@anthropic-ai/claude-code");}
    if t.id=="grok"{cmd.arg("--allow-scripts=@xai-official/grok");}
    cmd.arg("--prefix").arg(home.join(".local")).arg(t.package.unwrap()).env("npm_config_update_notifier","false");cmd
}
pub fn should_autostart(state: &Path) -> bool { !state.join("welcome-dismissed").is_file() }
pub fn dismiss(state: &Path) -> io::Result<()> { fs::create_dir_all(state)?; fs::write(state.join("welcome-dismissed"), b"1\n") }
pub fn safe_archive(list: &str) -> bool {
    !list.trim().is_empty() && list.lines().all(|line| {
        let p=Path::new(line);
        !p.is_absolute() && p.components().all(|c|matches!(c,Component::Normal(_))) &&
        p.components().next().is_some_and(|c|c.as_os_str()=="VSCode-linux-arm64")
    })
}
pub fn installed(home: &Path, t: &Tool) -> bool { home.join(".local/bin").join(t.binary).is_file() }
fn vscode_launcher(vm: bool) -> String {
    format!("#!/bin/sh\n# Managed by AI Tools Setup\nexec \"$HOME/.local/share/pi-ai-tools/vscode/bin/code\" --ozone-platform=wayland {}\"$@\"\n",if vm {"--disable-gpu "}else{""})
}
pub(crate) fn run(cmd: &mut Command, log: &File) -> Result<(),String> {
    let mut child=cmd.stdin(Stdio::null()).stdout(log.try_clone().map_err(|e|e.to_string())?).stderr(log.try_clone().map_err(|e|e.to_string())?).spawn().map_err(|e|e.to_string())?;
    let start=Instant::now();
    loop {
        if let Some(s)=child.try_wait().map_err(|e|e.to_string())? { return if s.success(){Ok(())}else{Err(format!("Installer exited with {s}. See the installation log."))}; }
        if start.elapsed()>Duration::from_secs(600) {let _=child.kill();let _=child.wait();return Err("Installer timed out. Check your connection and retry.".into());}
        thread::sleep(Duration::from_millis(150));
    }
}
pub(crate) fn fetch(url: &str, file: &Path, log: &File) -> Result<(),String> {
    run(Command::new("/usr/bin/curl").args(["--fail","--silent","--show-error","--location","--retry","2","--retry-delay","2","--proto","=https","--proto-redir","=https","--connect-timeout","15","--max-time","300","--output"]).arg(file).arg(url),log)
}
pub fn install(home: &Path, id: &str) -> Result<(),String> {
    let t=tool(id).ok_or("Unknown tool")?;
    let local=home.join(".local"); let state=home.join(".local/state/pi-ai-tools");
    fs::create_dir_all(&state).map_err(|e|e.to_string())?;
    fs::set_permissions(&state,fs::Permissions::from_mode(0o700)).map_err(|e|e.to_string())?;
    let logfile=state.join(format!("{}.log",t.id));
    let mut log=OpenOptions::new().create(true).append(true).open(&logfile).map_err(|e|e.to_string())?;
    writeln!(log,"\n=== {} install attempt {} ===",t.name,SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs()).map_err(|e|format!("Cannot write installation log: {e}"))?;
    let result=if t.package.is_some() {run(&mut npm_command(home,t), &log)} else if t.id=="vscode" {install_vscode(home,&log)} else {crate::vendor::install(home,t,&log)};
    if let Err(e)=result {let tail=fs::read_to_string(&logfile).unwrap_or_default();return Err(format!("{e} {}",error_summary(&tail)));}
    if !installed(home,t) {return Err("Installer finished but the executable is missing. Retry the installation.".into());}
    if t.package.is_some() || t.id=="vscode" {run(Command::new(local.join("bin").join(t.binary)).arg("--version"),&log).map_err(|e|format!("Installed files, but verification failed: {e} {}",error_summary(&fs::read_to_string(&logfile).unwrap_or_default())))?;}
    Ok(())
}
fn install_vscode(home: &Path, log: &File) -> Result<(),String> {
    let platform=crate::architecture::platform(std::env::consts::ARCH)?;
    let base=home.join(".local/share/pi-ai-tools");fs::create_dir_all(&base).map_err(|e|e.to_string())?;
    let stage=base.join("vscode-download");fs::create_dir_all(&stage).map_err(|e|e.to_string())?;
    let metadata=stage.join("release.json");
    fetch(&format!("https://update.code.visualstudio.com/api/update/{}/stable/latest",platform.download),&metadata,log)?;
    let meta:serde_json::Value=serde_json::from_slice(&fs::read(&metadata).map_err(|e|e.to_string())?).map_err(|e|e.to_string())?;
    let url=meta["url"].as_str().ok_or("Missing Microsoft download URL")?;
    if !url.starts_with("https://vscode.download.prss.microsoft.com/") && !url.starts_with("https://az764295.vo.msecnd.net/") {return Err("Unexpected Microsoft download host.".into());}
    let hash=meta["sha256hash"].as_str().ok_or("Missing Microsoft SHA-256 checksum")?;
    if hash.len()!=64 || !hash.bytes().all(|b|b.is_ascii_hexdigit()) {return Err("Invalid release checksum".into());}
    let archive=stage.join("vscode.tar.gz");fetch(url,&archive,log)?;
    let output=Command::new("/usr/bin/sha256sum").arg(&archive).output().map_err(|e|e.to_string())?;
    if !output.status.success() || String::from_utf8_lossy(&output.stdout).split_whitespace().next()!=Some(hash) {return Err("Download checksum mismatch. Please retry.".into());}
    let list=Command::new("/usr/bin/tar").arg("-tzf").arg(&archive).output().map_err(|e|e.to_string())?;
    if !list.status.success() || !safe_archive(&String::from_utf8_lossy(&list.stdout)) {return Err("Unsafe or invalid VS Code archive.".into());}
    let extracted=stage.join("unpacked");if extracted.exists(){fs::remove_dir_all(&extracted).map_err(|e|e.to_string())?;}fs::create_dir(&extracted).map_err(|e|e.to_string())?;
    run(Command::new("/usr/bin/tar").args(["--extract","--gzip","--no-same-owner","--strip-components=1","--file"]).arg(&archive).arg("--directory").arg(&extracted),log)?;
    if !extracted.join("bin/code").is_file(){return Err("VS Code archive has no launcher".into());}
    let target=base.join("vscode");let backup=base.join("vscode-previous");
    let bin=home.join(".local/bin");fs::create_dir_all(&bin).map_err(|e|e.to_string())?;
    let link=bin.join("code"); let dest=target.join("bin/code");
    let managed=fs::read_link(&link).ok().as_ref()==Some(&dest) || fs::read_to_string(&link).ok().is_some_and(|s|s.starts_with("#!/bin/sh\n# Managed by AI Tools Setup\n"));
    if fs::symlink_metadata(&link).is_ok() && !managed {return Err("An existing code command uses a different installation; it was left unchanged.".into());}
    if backup.exists(){fs::remove_dir_all(&backup).map_err(|e|e.to_string())?;}
    if target.exists(){fs::rename(&target,&backup).map_err(|e|e.to_string())?;}
    if let Err(e)=fs::rename(&extracted,&target){if backup.exists(){let _=fs::rename(&backup,&target);}return Err(e.to_string());}
    if fs::symlink_metadata(&link).is_ok(){fs::remove_file(&link).map_err(|e|e.to_string())?;}
    fs::write(&link,vscode_launcher(Path::new("/etc/pi-lfs-vm").exists())).map_err(|e|e.to_string())?;
    fs::set_permissions(&link,fs::Permissions::from_mode(0o755)).map_err(|e|e.to_string())?;
    let apps=home.join(".local/share/applications");fs::create_dir_all(&apps).map_err(|e|e.to_string())?;
    let escaped=link.to_string_lossy().replace('\\',"\\\\").replace('"',"\\\"").replace('`',"\\`").replace('$',"\\$").replace('%',"%%");
    fs::write(apps.join("pi-vscode.desktop"),format!("[Desktop Entry]\nType=Application\nName=Visual Studio Code\nComment=Code editor\nExec=\"{escaped}\" %U\nIcon={}/resources/app/resources/linux/code.png\nTerminal=false\nCategories=Development;IDE;\nMimeType=x-scheme-handler/vscode;\n",target.display())).map_err(|e|e.to_string())?;
    register_desktop(&apps,"pi-vscode.desktop","vscode",log)?;
    let _=fs::remove_file(archive);let _=fs::remove_dir_all(backup);
    Ok(())
}
pub fn state_path(home: &Path) -> PathBuf {std::env::var_os("XDG_STATE_HOME").map(PathBuf::from).filter(|p|p.is_absolute()).unwrap_or_else(||home.join(".local/state")).join("pi-ai-tools")}

