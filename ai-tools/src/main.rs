mod architecture;
mod core;
mod gui;
mod vendor;
use std::{env,fs::{self,OpenOptions},os::fd::AsRawFd,path::PathBuf};
extern "C" {fn geteuid()->u32;fn flock(fd:i32,operation:i32)->i32;}
fn main() {
    let args:Vec<_>=env::args().collect();
    if args.get(1).map(String::as_str)==Some("--version") {println!("Bravion Store {}",env!("CARGO_PKG_VERSION"));return;}
    let home=env::var_os("HOME").map(PathBuf::from).filter(|p|p.is_absolute()).expect("HOME must be an absolute path");
    if unsafe{geteuid()}==0 {eprintln!("Run AI Tools Setup as your desktop user, without sudo.");std::process::exit(1);}
    let state=core::state_path(&home);
    if args.iter().any(|a|a=="--autostart") && !core::should_autostart(&state){return;}
    fs::create_dir_all(&state).expect("Cannot create user state directory");
    let lock=OpenOptions::new().read(true).write(true).create(true).truncate(false).open(state.join("wizard.lock")).expect("Cannot open wizard lock");
    if unsafe{flock(lock.as_raw_fd(),2|4)}!=0{return;}
    let prefix=home.join(".local/bin");
    env::set_var("PATH",format!("{}:/usr/local/bin:/usr/bin:/bin",prefix.display()));
    if args.get(1).map(String::as_str)==Some("--install") {
        let id=args.get(2).map(String::as_str).unwrap_or("");
        if let Err(e)=core::install(&home,id){eprintln!("{e}");std::process::exit(1);}return;
    }
    unsafe{gui::run(home,state);}
}
