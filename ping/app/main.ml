open Lwt 
open Printf
open Net

let ip = match Nettypes.ipv4_addr_of_string "10.0.0.2" with Some x -> x |None -> assert false
let nm = match Nettypes.ipv4_addr_of_string "255.255.255.0" with Some x -> x |None -> assert false

let rec watchdog () =
  let open Gc in
  let s = stat () in
  printf "blocks: l=%d f=%d\n%!" s.live_blocks s.free_blocks;
  OS.Time.sleep 2. >>
  watchdog ()

let main () =
  lwt mgr, mgr_t = Manager.create () in
  mgr_t

let _ = OS.Main.run (main ())
