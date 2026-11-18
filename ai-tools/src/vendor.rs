use crate::core::{self,Tool};
use std::{fs::{self,File},path::{Path,Component},process::Command,os::unix::fs::PermissionsExt};

#[derive(Debug)]
pub struct Release {pub url:String,pub checksum:Option<String>}
pub fn claude_release(index:&str)->Result<Release,String> {claude_release_for_arch(index,"arm64")}
pub fn claude_release_for_arch(index:&str,arch:&str)->Result<Release,String> {
    let mut releases=Vec::new();
    for paragraph in index.split("\n\n") {
        let fields:std::collections::HashMap<_,_>=paragraph.lines().filter_map(|l|l.split_once(": ")).collect();
        if fields.get("Package")!=Some(&"claude-desktop") || fields.get("Architecture")!=Some(&arch){continue;}
        let path=*fields.get("Filename").ok_or("Claude package has no download path")?;
        let hash=*fields.get("SHA256").ok_or("Claude package has no checksum")?;
        if !path.starts_with("pool/main/c/claude-desktop/") || path.contains("..") || hash.len()!=64 || !hash.bytes().all(|b|b.is_ascii_hexdigit()){return Err("Invalid Claude package metadata".into());}
        let key:Vec<u64>=fields.get("Version").unwrap_or(&"").split(|c:char|!c.is_ascii_digit()).filter_map(|s|s.parse().ok()).collect();
        releases.push((key,Release{url:format!("https://downloads.claude.ai/claude-desktop/apt/stable/{path}"),checksum:Some(hash.into())}));
    }
    releases.into_iter().max_by(|a,b|a.0.cmp(&b.0)).map(|(_,r)|r).ok_or_else(||format!("No Claude Desktop package was found for {arch}."))
}
pub fn safe_payload(list:&str)->bool {
    !list.trim().is_empty() && list.lines().all(|l|!Path::new(l).is_absolute() && Path::new(l).components().all(|c|matches!(c,Component::Normal(_)|Component::CurDir)))
}

pub fn install(home:&Path,t:&Tool,log:&File)->Result<(),String>{
    let platform=crate::architecture::platform(std::env::consts::ARCH)?;
    let base=home.join(".local/share/pi-ai-tools");fs::create_dir_all(&base).map_err(|e|e.to_string())?;
    let stage=base.join(format!("{}-download",t.id));fs::create_dir_all(&stage).map_err(|e|e.to_string())?;
    let release=match t.id {
        "chatgpt-desktop"=>Release{url:format!("https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_{}.deb",platform.deb),checksum:None},
        "claude-desktop"=>{let meta=stage.join("Packages");core::fetch(&format!("https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-{}/Packages",platform.deb),&meta,log)?;claude_release_for_arch(&fs::read_to_string(meta).map_err(|e|e.to_string())?,platform.deb)?},
        "grok-desktop"=>{let meta=stage.join("release.json");core::fetch(&format!("https://api2.cursor.sh/updates/api/download/stable/{}/sand",platform.download),&meta,log)?;let value:serde_json::Value=serde_json::from_slice(&fs::read(meta).map_err(|e|e.to_string())?).map_err(|e|e.to_string())?;let url=value["debUrl"].as_str().ok_or("Grok release feed has no compatible Debian package")?;if !url.starts_with("https://downloads.cursor.com/grokbot/stable/"){return Err("Unexpected Grok download host".into());}Release{url:url.into(),checksum:None}},
        _=>return Err("Unknown desktop app".into()),
    };
    let package=stage.join("package.deb");core::fetch(&release.url,&package,log)?;
    if let Some(hash)=release.checksum {
        let out=Command::new("/usr/bin/sha256sum").arg(&package).output().map_err(|e|e.to_string())?;
        if !out.status.success() || String::from_utf8_lossy(&out.stdout).split_whitespace().next()!=Some(&hash){return Err("The desktop download did not match the publisher checksum. Retry.".into());}
    }
    let members=Command::new("/usr/bin/ar").arg("t").arg(&package).output().map_err(|e|e.to_string())?;
    if !members.status.success(){return Err("The downloaded file is not a valid desktop package".into());}
    let listing=String::from_utf8_lossy(&members.stdout);
    let member=listing.lines().find(|s|matches!(*s,"data.tar.xz"|"data.tar.gz"|"data.tar.zst"|"data.tar")).ok_or("The package has no supported application archive")?;
    let payload=stage.join(member);
    let output=File::create(&payload).map_err(|e|e.to_string())?;
    let status=Command::new("/usr/bin/ar").arg("p").arg(&package).arg(member).stdout(output).stderr(log.try_clone().map_err(|e|e.to_string())?).status().map_err(|e|e.to_string())?;
    if !status.success(){return Err("Could not unpack the desktop download".into());}
    let paths=Command::new("/usr/bin/tar").arg("-tf").arg(&payload).output().map_err(|e|e.to_string())?;
    if !paths.status.success() || !safe_payload(&String::from_utf8_lossy(&paths.stdout)){return Err("The desktop package contains unsafe or invalid paths".into());}
    let unpack=stage.join("unpacked");if unpack.exists(){fs::remove_dir_all(&unpack).map_err(|e|e.to_string())?;}fs::create_dir(&unpack).map_err(|e|e.to_string())?;
    core::run(Command::new("/usr/bin/tar").args(["--extract","--no-same-owner","--file"]).arg(&payload).arg("--directory").arg(&unpack),log)?;
    let (exe,icon)=match t.id {
        "chatgpt-desktop"=>("usr/lib/chatgpt/ChatGPT","usr/share/pixmaps/chatgpt.png"),
        "claude-desktop"=>("usr/lib/claude-desktop/claude-desktop","usr/share/icons/hicolor/256x256/apps/claude-desktop.png"),
        _=>("opt/Grok Bot/grok-bot","usr/share/icons/hicolor/256x256/apps/grok-bot.png"),
    };
    let binary=unpack.join(exe);if !binary.is_file(){return Err("The publisher changed the app layout. The previous installation has been kept.".into());}
    let dependencies=Command::new("/usr/bin/ldd").arg(&binary).output().map_err(|e|e.to_string())?;
    let deps=String::from_utf8_lossy(&dependencies.stdout);
    let missing:Vec<_>=deps.lines().filter(|l|l.contains("not found")).map(str::trim).collect();
    if !dependencies.status.success() || !missing.is_empty(){return Err(format!("This desktop build needs additional system libraries: {}",missing.join(", ")));}
    let target=base.join(t.id);let previous=base.join(format!("{}-previous",t.id));
    let bin=home.join(".local/bin");fs::create_dir_all(&bin).map_err(|e|e.to_string())?;let launcher=bin.join(t.binary);
    if fs::symlink_metadata(&launcher).is_ok() && !fs::read_to_string(&launcher).ok().is_some_and(|s|s.starts_with("#!/bin/sh\n# Managed by AI Tools Setup\n")){return Err("An existing launcher belongs to another installation and was left unchanged.".into());}
    if previous.exists(){fs::remove_dir_all(&previous).map_err(|e|e.to_string())?;}
    if target.exists(){fs::rename(&target,&previous).map_err(|e|e.to_string())?;}
    if let Err(e)=fs::rename(&unpack,&target){if previous.exists(){let _=fs::rename(&previous,&target);}return Err(e.to_string());}
    let vm=if Path::new("/etc/pi-lfs-vm").exists(){" --disable-gpu"}else{""};
    fs::write(&launcher,format!("#!/bin/sh\n# Managed by AI Tools Setup\nexec \"$HOME/.local/share/pi-ai-tools/{}/{exe}\" --ozone-platform=wayland{vm} \"$@\"\n",t.id)).map_err(|e|e.to_string())?;
    fs::set_permissions(&launcher,fs::Permissions::from_mode(0o755)).map_err(|e|e.to_string())?;
    let apps=home.join(".local/share/applications");fs::create_dir_all(&apps).map_err(|e|e.to_string())?;
    let escape=|p:&Path|p.to_string_lossy().replace('\\',"\\\\").replace('"',"\\\"").replace('`',"\\`").replace('$',"\\$").replace('%',"%%");
    let categories=if t.id=="chatgpt-desktop"{"Development;Office;"}else{"Development;Utility;"};
    let filename=format!("pi-{}.desktop",t.id);
    fs::write(apps.join(&filename),format!("[Desktop Entry]\nType=Application\nName={}\nExec=\"{}\" %U\nIcon={}\nTerminal=false\nCategories={categories}\nMimeType={};\n",t.name,escape(&launcher),target.join(icon).display(),core::private_schemes(t.id).join(";"))).map_err(|e|e.to_string())?;
    core::register_desktop(&apps,&filename,t.id,log)?;
    let _=fs::remove_file(package);let _=fs::remove_file(payload);let _=fs::remove_dir_all(previous);
    Ok(())
}

#[cfg(test)]mod tests{
 use super::*;
 #[test]fn vendor_paths_reject_escape_but_allow_debian_relative_paths(){assert!(safe_payload("./usr/lib/app/app\n./usr/share/icons/icon.png"));for s in ["/etc/passwd","./usr/../../etc/passwd",""]{assert!(!safe_payload(s));}}
 #[test]fn claude_metadata_selects_latest_arm64_and_requires_integrity(){let h="a".repeat(64);let a=format!("Package: claude-desktop\nVersion: 1.9.0\nArchitecture: arm64\nFilename: pool/main/c/claude-desktop/old.deb\nSHA256: {h}\n\nPackage: claude-desktop\nVersion: 1.10.0\nArchitecture: arm64\nFilename: pool/main/c/claude-desktop/new.deb\nSHA256: {h}");assert!(claude_release(&a).unwrap().url.ends_with("new.deb"));assert!(claude_release(&a.replace(&h,"bad")).is_err());}
}

#[cfg(test)]
mod architecture_tests {
 use super::*;
 #[test] fn claude_feed_selects_cpu_architecture_before_latest_version() {
  let h="a".repeat(64);
  let index=format!("Package: claude-desktop\nVersion: 9.0\nArchitecture: arm64\nFilename: pool/main/c/claude-desktop/arm.deb\nSHA256: {h}\n\nPackage: claude-desktop\nVersion: 3.0\nArchitecture: amd64\nFilename: pool/main/c/claude-desktop/amd.deb\nSHA256: {h}");
  assert!(claude_release_for_arch(&index,"amd64").unwrap().url.ends_with("amd.deb"));
  assert!(claude_release_for_arch(&index,"arm64").unwrap().url.ends_with("arm.deb"));
 }
}
