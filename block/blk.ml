open Printf
open Lwt

let consume s =
  let c = ref 0 in
  printf "start consume\n%!";
  Lwt_stream.iter_s (fun view ->
    incr c;
    printf "[%d %d] %!" !c (OS.Istring.length view);
    OS.Time.sleep 0.1
  ) s >>
  return (printf "end\n%!")

let main () =
  lwt mgr, mgr_t = Net.Manager.create () in
  lwt vbd_ids = OS.Blkif.enumerate () in
  lwt vbd, _ = match vbd_ids with |[x] -> OS.Blkif.create x |_ -> fail (Failure "1 vbd only") in
  OS.Time.sleep 1. >>
  lwt fs = Block.RO.create vbd in
  printf "sanity1\n%!";
  Block.RO.read fs "t1" >>= consume >>
  Block.RO.read fs "t2" >>= consume >>
  return ()

let _ = OS.Main.run (main ())
