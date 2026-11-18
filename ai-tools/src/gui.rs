use crate::core::{self, TOOLS};
use std::{ffi::{c_char,c_void,CStr,CString},fs::OpenOptions,io::Write,path::PathBuf,process::Command,ptr,sync::mpsc::{self,Receiver,Sender},time::{Duration,Instant,SystemTime,UNIX_EPOCH}};
type W=*mut c_void;
const N:usize=TOOLS.len();
#[link(name="gtk-3")]
extern "C" {
 fn gtk_init_check(argc:*mut i32,argv:*mut *mut *mut c_char)->i32;
 fn gtk_window_set_icon_from_file(w:W,f:*const c_char,error:W)->i32;fn gtk_window_new(kind:i32)->W;fn gtk_window_set_title(w:W,t:*const c_char);fn gtk_window_set_default_size(w:W,x:i32,y:i32);fn gtk_window_set_position(w:W,pos:i32);fn gtk_window_maximize(w:W);
 fn gtk_box_new(orientation:i32,spacing:i32)->W;fn gtk_box_pack_start(b:W,c:W,expand:i32,fill:i32,pad:u32);fn gtk_box_pack_end(b:W,c:W,expand:i32,fill:i32,pad:u32);
 fn gtk_container_add(w:W,c:W);fn gtk_container_set_border_width(w:W,width:u32);
 fn gtk_label_new(t:*const c_char)->W;fn gtk_label_set_text(w:W,t:*const c_char);fn gtk_label_set_xalign(w:W,x:f32);fn gtk_label_set_line_wrap(w:W,v:i32);fn gtk_label_set_max_width_chars(w:W,n:i32);fn gtk_label_set_lines(w:W,n:i32);fn gtk_label_set_ellipsize(w:W,mode:i32);
 fn gtk_button_new_with_label(t:*const c_char)->W;fn gtk_button_set_label(w:W,t:*const c_char);
 fn gtk_widget_set_sensitive(w:W,v:i32);fn gtk_widget_show_all(w:W);fn gtk_widget_set_size_request(w:W,x:i32,y:i32);fn gtk_widget_set_tooltip_text(w:W,t:*const c_char);fn gtk_widget_get_style_context(w:W)->W;
 fn gtk_style_context_add_class(w:W,s:*const c_char);fn gtk_style_context_remove_class(w:W,s:*const c_char);fn gtk_style_context_add_provider_for_screen(screen:W,provider:W,priority:u32);
 fn gtk_css_provider_new()->W;fn gtk_css_provider_load_from_data(p:W,data:*const c_char,length:isize,error:W)->i32;
 fn gtk_progress_bar_new()->W;fn gtk_progress_bar_pulse(w:W);fn gtk_progress_bar_set_fraction(w:W,f:f64);
 fn gtk_search_entry_new()->W;fn gtk_entry_get_text(w:W)->*const c_char;fn gtk_entry_set_placeholder_text(w:W,t:*const c_char);
 fn gtk_scrolled_window_new(h:W,v:W)->W;fn gtk_scrolled_window_set_policy(w:W,h:i32,v:i32);
 fn gtk_flow_box_new()->W;fn gtk_flow_box_set_selection_mode(w:W,v:i32);fn gtk_flow_box_set_min_children_per_line(w:W,n:u32);fn gtk_flow_box_set_max_children_per_line(w:W,n:u32);fn gtk_flow_box_set_column_spacing(w:W,n:u32);fn gtk_flow_box_set_row_spacing(w:W,n:u32);fn gtk_flow_box_set_homogeneous(w:W,n:i32);fn gtk_flow_box_insert(w:W,c:W,pos:i32);fn gtk_flow_box_set_filter_func(w:W,f:extern "C" fn(W,W)->i32,data:W,destroy:W);fn gtk_flow_box_invalidate_filter(w:W);fn gtk_bin_get_child(w:W)->W;
 fn gtk_image_new_from_pixbuf(w:W)->W;
 fn gtk_main();fn gtk_main_quit();
}
#[link(name="gdk-3")]extern "C" {fn gdk_screen_get_default()->W;}
#[link(name="gdk_pixbuf-2.0")]extern "C" {fn gdk_pixbuf_new_from_file_at_scale(f:*const c_char,w:i32,h:i32,aspect:i32,error:W)->W;}
#[link(name="gobject-2.0")]extern "C" {fn g_signal_connect_data(w:W,s:*const c_char,cb:*const c_void,data:W,destroy:W,flags:u32)->u64;fn g_object_set_data(w:W,key:*const c_char,data:W);fn g_object_get_data(w:W,key:*const c_char)->W;fn g_object_unref(w:W);}
#[link(name="glib-2.0")]extern "C" {fn g_timeout_add(ms:u32,cb:extern "C" fn(W)->i32,data:W)->u32;}
fn c(s:&str)->CString{CString::new(s.replace('\0'," ")).unwrap()}
unsafe fn class(w:W,s:&str){gtk_style_context_add_class(gtk_widget_get_style_context(w),c(s).as_ptr());}
unsafe fn label(s:&str,style:&str)->W{let w=gtk_label_new(c(s).as_ptr());gtk_label_set_xalign(w,0.0);gtk_label_set_line_wrap(w,1);class(w,style);w}
unsafe fn text(w:W,s:&str){gtk_label_set_text(w,c(s).as_ptr());gtk_widget_set_tooltip_text(w,c(s).as_ptr());}
unsafe fn button(s:&str,style:&str)->W{let w=gtk_button_new_with_label(c(s).as_ptr());class(w,style);w}
unsafe fn connect(w:W,signal:&str,cb:*const c_void,data:W){g_signal_connect_data(w,c(signal).as_ptr(),cb,data,ptr::null_mut(),0);}
const CSS:&str=r#"
* {font-family: 'Liberation Sans', sans-serif; font-size: 14px;}
window {background: #111722; color: #e9edf5;}
headerbar, .titlebar {background: #182232; color: #eef4ff; border-bottom: 1px solid #34445b; box-shadow: none;}
.title {font-size: 27px; font-weight: 700; color: #f4f7fc;}
.subtitle {font-size: 14px; color: #a4b2c8;}
.small {font-size: 12px; color: #9caec5;}
.app-card {background: #1c2533; border: 1px solid #324055; border-radius: 16px; padding: 19px;}
.app-name {font-size: 18px; font-weight: 700; color: #f2f5fa;}
.publisher {font-size: 12px; color: #9fb1ca;}
.description {font-size: 14px; color: #c3cede;}
.badge {font-size: 11px; font-weight: 700; color: #8be0d0; background: #243e46; border-radius: 7px; padding: 4px 8px;}
.status {font-size: 12px; color: #9fb1ca;}
.error {color: #ffb4a8;}
.success {color: #8be0b2;}
button {background: #29374b; color: #edf2fa; border: 1px solid #40516c; border-radius: 9px; padding: 9px 15px; box-shadow: none; text-shadow: none;}
button:hover {background: #354863;}
button:disabled {color: #76859b; background: #202a39;}
.primary {background: #67d8c3; color: #102c2b; border-color: #67d8c3; font-weight: 700;}
.primary:hover {background: #8be9d6;}
.filter {padding: 7px 17px;}
.selected {background: #3a536c; border-color: #7da9cb;}
.app-icon {font-size: 24px; font-weight: 700; border-radius: 12px; padding: 10px; color: white;}
.openai {background: #216f63;} .anthropic {background: #a6674c;} .xai {background: #36485e;} .vscode {background: #126ca1;}
entry {background: #1c2533; color: #edf2fa; border: 1px solid #40516c; border-radius: 10px; padding: 10px;}
progressbar trough {background: #303e52; min-height: 4px; border: none; border-radius: 3px;}
progressbar progress {background: #67d8c3; min-height: 4px; border: none; border-radius: 3px;}
scrolledwindow {border: none;}
"#;
enum Event {Installed(usize,Result<(),String>),Launched(usize,Result<(),String>)}
struct Ui {home:PathBuf,state:PathBuf,flow:W,filter:String,query:String,filters:[W;3],installs:[W;N],opens:[W;N],labels:[W;N],bars:[W;N],footer:W,done:W,busy:Option<usize>,tx:Sender<Event>,rx:Receiver<Event>}
struct Action {ui:*mut Ui,index:usize}
struct Filter {ui:*mut Ui,index:usize}
extern "C" fn match_card(child:W,data:W)->i32{unsafe{let u=&*(data as *const Ui);let card=gtk_bin_get_child(child);let index=g_object_get_data(card,c("app-index").as_ptr()) as usize-1;core::catalog_matches(&TOOLS[index],&u.filter,&u.query) as i32}}
extern "C" fn search_changed(w:W,data:W){unsafe{let flow;{let u=&mut *(data as *mut Ui);u.query=CStr::from_ptr(gtk_entry_get_text(w)).to_string_lossy().into_owned();flow=u.flow;}gtk_flow_box_invalidate_filter(flow);}}
extern "C" fn filter_clicked(_:W,data:W){unsafe{let f=&*(data as *const Filter);let flow;{let u=&mut *f.ui;u.filter=["All","Desktop","Terminal"][f.index].into();for i in 0..3{let s=gtk_widget_get_style_context(u.filters[i]);if i==f.index{gtk_style_context_add_class(s,c("selected").as_ptr());}else{gtk_style_context_remove_class(s,c("selected").as_ptr());}}flow=u.flow;}gtk_flow_box_invalidate_filter(flow);}}
unsafe fn set_status(u:&Ui,i:usize,s:&str,failed:bool){text(u.labels[i],s);let ctx=gtk_widget_get_style_context(u.labels[i]);gtk_style_context_remove_class(ctx,c("error").as_ptr());gtk_style_context_remove_class(ctx,c("success").as_ptr());gtk_style_context_add_class(ctx,c(if failed{"error"}else{"success"}).as_ptr());}
extern "C" fn install_clicked(_:W,data:W){unsafe{
 let a=&*(data as *const Action);let u=&mut *a.ui;if u.busy.is_some(){return;}let i=a.index;u.busy=Some(i);
 for b in u.installs{gtk_widget_set_sensitive(b,0);}gtk_widget_set_sensitive(u.done,0);
 set_status(u,i,"Downloading and installing from the official publisher...",false);text(u.footer,&format!("Installing {}. You can keep browsing.",TOOLS[i].name));
 let home=u.home.clone();let tx=u.tx.clone();std::thread::spawn(move||{let result=core::install(&home,TOOLS[i].id);let _=tx.send(Event::Installed(i,result));});
}}
extern "C" fn open_clicked(_:W,data:W){unsafe{
 let a=&*(data as *const Action);let u=&mut *a.ui;let i=a.index;let t=&TOOLS[i];let exe=u.home.join(".local/bin").join(t.binary);
 if t.package.is_some(){
  let result=Command::new("/usr/bin/cosmic-term").args(["--","/usr/bin/bash","-c","\"$1\"; status=$?; if [ \"$status\" -ne 0 ]; then printf '\\nThe tool exited with status %s. Press Enter to close.\\n' \"$status\"; read -r answer; fi","pi-ai-launch"]).arg(exe).spawn();
  if let Err(e)=result{set_status(u,i,&format!("Could not open terminal: {e}"),true);}else{text(u.footer,&format!("{} opened in Terminal. Sign in there.",t.name));}return;
 }
 let logdir=u.home.join(".local/state/pi-ai-tools");let _=std::fs::create_dir_all(&logdir);let logpath=logdir.join(format!("{}-launch.log",t.id));
 let mut log=match OpenOptions::new().create(true).append(true).open(&logpath){Ok(f)=>f,Err(e)=>{set_status(u,i,&format!("Could not create launch log: {e}"),true);return;}};
 if let Err(e)=writeln!(log,"\n=== {} launch attempt {} ===",t.name,SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs()){set_status(u,i,&format!("Could not write launch log: {e}"),true);return;}
 let stderr=match log.try_clone(){Ok(f)=>f,Err(e)=>{set_status(u,i,&e.to_string(),true);return;}};
 let mut child=match Command::new(exe).stdout(log).stderr(stderr).spawn(){Ok(ch)=>ch,Err(e)=>{set_status(u,i,&format!("Could not open app: {e}"),true);return;}};
 text(u.footer,&format!("Opening {}...",t.name));let tx=u.tx.clone();std::thread::spawn(move||{
  let start=Instant::now();loop{match child.try_wait(){Ok(Some(status))=>{let result=if status.success(){Ok(())}else{Err(format!("Launch failed ({status}). {}",core::error_summary(&std::fs::read_to_string(&logpath).unwrap_or_default())))};let _=tx.send(Event::Launched(i,result));break;},Ok(None)=>{},Err(e)=>{let _=tx.send(Event::Launched(i,Err(e.to_string())));break;}}
  if start.elapsed()>Duration::from_secs(12){let _=tx.send(Event::Launched(i,Ok(())));break;}std::thread::sleep(Duration::from_millis(200));}
 });
}}
extern "C" fn logs_clicked(_:W,data:W){unsafe{let a=&*(data as *const Action);let u=&mut *a.ui;let file=u.home.join(".local/state/pi-ai-tools").join(format!("{}.log",TOOLS[a.index].id));if file.is_file(){let _=Command::new("/usr/bin/cosmic-edit").arg(file).spawn();}else{text(u.footer,"No install log yet. Choose Install to start.");}}}
extern "C" fn done_clicked(_:W,data:W){unsafe{let u=&mut *(data as *mut Ui);if u.busy.is_none(){match core::dismiss(&u.state){Ok(())=>gtk_main_quit(),Err(e)=>text(u.footer,&format!("Could not save setup state: {e}"))}}}}
extern "C" fn close_requested(_:W,_:W,data:W)->i32{unsafe{let u=&mut *(data as *mut Ui);if u.busy.is_some(){text(u.footer,"An installation is still running. Please wait for its result.");1}else{gtk_main_quit();0}}}
extern "C" fn poll(data:W)->i32{unsafe{let u=&mut *(data as *mut Ui);while let Ok(event)=u.rx.try_recv(){match event{
 Event::Installed(i,result)=>{u.busy=None;gtk_widget_set_sensitive(u.done,1);for b in u.installs{gtk_widget_set_sensitive(b,1);}gtk_widget_set_sensitive(u.opens[i],core::installed(&u.home,&TOOLS[i]) as i32);gtk_progress_bar_set_fraction(u.bars[i],1.0);match result{Ok(())=>{set_status(u,i,"Installed. Ready to open.",false);gtk_button_set_label(u.installs[i],c("Reinstall").as_ptr());text(u.footer,&format!("{} is ready. Choose Open to get started.",TOOLS[i].name));},Err(error)=>{set_status(u,i,&error,true);gtk_button_set_label(u.installs[i],c("Retry").as_ptr());text(u.footer,&format!("{} was not installed successfully. Its error is shown on the card; choose Log for details.",TOOLS[i].name));}}},
 Event::Launched(i,result)=>match result{Ok(())=>text(u.footer,&format!("{} opened. Complete sign-in in the app.",TOOLS[i].name)),Err(e)=>{set_status(u,i,&format!("Could not open: {e}"),true);text(u.footer,"The app could not start. The launch error is shown on its card.");}},
 }}if let Some(i)=u.busy{gtk_progress_bar_pulse(u.bars[i]);}1}}
pub unsafe fn run(home:PathBuf,state:PathBuf){
 if gtk_init_check(ptr::null_mut(),ptr::null_mut())==0{eprintln!("The App Store needs a graphical desktop session.");return;}
 let provider=gtk_css_provider_new();gtk_css_provider_load_from_data(provider,c(CSS).as_ptr(),-1,ptr::null_mut());gtk_style_context_add_provider_for_screen(gdk_screen_get_default(),provider,800);
 let local_brand=home.join(".local/share/pi-ai-tools/icons/bravion-store.png");let brand_path=if local_brand.is_file(){local_brand.to_string_lossy().into_owned()}else{"/usr/share/pi-ai-tools/icons/bravion-store.png".into()};
 let window=gtk_window_new(0);gtk_window_set_title(window,c("Bravion Store").as_ptr());gtk_window_set_icon_from_file(window,c(&brand_path).as_ptr(),ptr::null_mut());gtk_window_set_default_size(window,980,720);gtk_window_set_position(window,1);
 let body=gtk_box_new(1,16);gtk_container_set_border_width(body,24);gtk_container_add(window,body);
 let heading=gtk_box_new(0,20);let brand=gdk_pixbuf_new_from_file_at_scale(c(&brand_path).as_ptr(),72,72,1,ptr::null_mut());if !brand.is_null(){let logo=gtk_image_new_from_pixbuf(brand);g_object_unref(brand);gtk_box_pack_start(heading,logo,0,0,0);}let words=gtk_box_new(1,5);gtk_box_pack_start(words,label("Bravion Store","title"),0,0,0);gtk_box_pack_start(words,label("Official AI apps and developer tools. Choose what you need.","subtitle"),0,0,0);gtk_box_pack_start(heading,words,1,1,0);let search=gtk_search_entry_new();gtk_entry_set_placeholder_text(search,c("Search apps").as_ptr());gtk_widget_set_size_request(search,240,-1);gtk_box_pack_end(heading,search,0,0,0);gtk_box_pack_start(body,heading,0,0,0);
 let nav=gtk_box_new(0,8);let mut filters=[ptr::null_mut();3];for (i,name) in ["All","Desktop","Terminal"].iter().enumerate(){filters[i]=button(name,"filter");if i==0{class(filters[i],"selected");}gtk_box_pack_start(nav,filters[i],0,0,0);}
 let git=Command::new("/usr/bin/git").arg("--version").output().ok().filter(|o|o.status.success()).map(|o|String::from_utf8_lossy(&o.stdout).trim().to_string()).unwrap_or_else(||"Git check unavailable".into());gtk_box_pack_end(nav,label(&format!("{git}  |  Node + npm included"),"small"),0,0,0);gtk_box_pack_start(body,nav,0,0,0);
 let scroll=gtk_scrolled_window_new(ptr::null_mut(),ptr::null_mut());gtk_scrolled_window_set_policy(scroll,2,1);let flow=gtk_flow_box_new();gtk_flow_box_set_selection_mode(flow,0);gtk_flow_box_set_min_children_per_line(flow,1);gtk_flow_box_set_max_children_per_line(flow,2);gtk_flow_box_set_homogeneous(flow,1);gtk_flow_box_set_column_spacing(flow,16);gtk_flow_box_set_row_spacing(flow,16);gtk_container_add(scroll,flow);gtk_box_pack_start(body,scroll,1,1,0);
 let mut installs=[ptr::null_mut();N];let mut opens=installs;let mut labels=installs;let mut bars=installs;let mut logs=installs;
 for i in 0..N{
  let t=&TOOLS[i];let meta=core::info(t);let card=gtk_box_new(1,12);class(card,"app-card");gtk_widget_set_size_request(card,390,-1);g_object_set_data(card,c("app-index").as_ptr(),(i+1) as W);
  let header=gtk_box_new(0,12);let pix=gdk_pixbuf_new_from_file_at_scale(c(&format!("/usr/share/pi-ai-tools/icons/{}.png",meta.style)).as_ptr(),48,48,1,ptr::null_mut());let icon=if pix.is_null(){let w=label(meta.initials,"app-icon");class(w,meta.style);w}else{let w=gtk_image_new_from_pixbuf(pix);g_object_unref(pix);w};gtk_box_pack_start(header,icon,0,0,0);
  let title=gtk_box_new(1,4);gtk_box_pack_start(title,label(t.name,"app-name"),0,0,0);gtk_box_pack_start(title,label(meta.publisher,"publisher"),0,0,0);gtk_box_pack_start(header,title,1,1,0);gtk_box_pack_end(header,label(core::category(t),"badge"),0,0,0);gtk_box_pack_start(card,header,0,0,0);
  let description=label(meta.description,"description");gtk_label_set_max_width_chars(description,46);gtk_widget_set_size_request(description,-1,48);gtk_box_pack_start(card,description,0,0,0);
  labels[i]=label(if core::installed(&home,t){"Installed. Ready to open."}else{"Download when you choose Install."},"status");gtk_label_set_max_width_chars(labels[i],46);gtk_label_set_lines(labels[i],3);gtk_label_set_ellipsize(labels[i],3);gtk_widget_set_size_request(labels[i],-1,44);gtk_box_pack_start(card,labels[i],0,0,0);
  bars[i]=gtk_progress_bar_new();gtk_box_pack_start(card,bars[i],0,0,0);let actions=gtk_box_new(0,8);logs[i]=button("Log","small");opens[i]=button("Open","secondary");gtk_widget_set_sensitive(opens[i],core::installed(&home,t) as i32);installs[i]=button(if core::installed(&home,t){"Reinstall"}else{"Install"},"primary");gtk_box_pack_start(actions,logs[i],0,0,0);gtk_box_pack_end(actions,installs[i],0,0,0);gtk_box_pack_end(actions,opens[i],0,0,0);gtk_box_pack_start(card,actions,0,0,0);gtk_flow_box_insert(flow,card,-1);
 }
 let footerrow=gtk_box_new(0,16);let footwords=gtk_box_new(1,4);let footer=label("Downloads are optional. Installations stay in your account; sign in directly with each provider.","small");gtk_label_set_max_width_chars(footer,100);gtk_box_pack_start(footwords,footer,0,0,0);gtk_box_pack_start(footwords,label(&format!("App Store {}  |  Desktop previews are experimental on LFS.",env!("CARGO_PKG_VERSION")),"small"),0,0,0);gtk_box_pack_start(footerrow,footwords,1,1,0);let done=button("Done / Skip","secondary");gtk_box_pack_end(footerrow,done,0,0,0);gtk_box_pack_end(body,footerrow,0,0,0);
 let (tx,rx)=mpsc::channel();let u=Box::into_raw(Box::new(Ui{home,state,flow,filter:"All".into(),query:String::new(),filters,installs,opens,labels,bars,footer,done,busy:None,tx,rx}));
 for i in 0..N{let a=Box::into_raw(Box::new(Action{ui:u,index:i}));connect(installs[i],"clicked",install_clicked as *const c_void,a as W);connect(opens[i],"clicked",open_clicked as *const c_void,a as W);connect(logs[i],"clicked",logs_clicked as *const c_void,a as W);}
 for i in 0..3{let f=Box::into_raw(Box::new(Filter{ui:u,index:i}));connect(filters[i],"clicked",filter_clicked as *const c_void,f as W);}
 connect(search,"search-changed",search_changed as *const c_void,u as W);connect(done,"clicked",done_clicked as *const c_void,u as W);connect(window,"delete-event",close_requested as *const c_void,u as W);gtk_flow_box_set_filter_func(flow,match_card,u as W,ptr::null_mut());g_timeout_add(150,poll,u as W);gtk_window_maximize(window);gtk_widget_show_all(window);gtk_main();
}
