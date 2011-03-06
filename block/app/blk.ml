open Printf
open Lwt

type file = {
  name: string;
  offset: int64;
  len: int64;
}

let read_file_info vbd =
  let files = Hashtbl.create 7 in
  let rec read_page off = 
    lwt v = OS.Blkif.read_page vbd off in
    let rec parse_page num =
      let loff = num * 512 in
      match OS.Istring.View.to_uint32_be v loff with
      |0xdeadbeefl ->
        let offset = OS.Istring.View.to_uint64_be v (loff+4) in
        let len = OS.Istring.View.to_uint64_be v (loff+12) in
        let namelen = OS.Istring.View.to_uint32_be v (loff+20) in
        let name = OS.Istring.View.to_string v (loff+24) (Int32.to_int namelen) in
        Hashtbl.add files name { name; offset; len };
        printf "Read file: %s %Lu[%Lu]\n%!" name offset len;
        if num = 7 then
          read_page (Int64.add off 8L)
        else
          parse_page (num+1)
      |_ -> return ()
    in
    parse_page 0 in
  read_page 0L >>
  return files
  
let main () =
  lwt ids = OS.Blkif.enumerate () in
  Lwt_list.iter_s (fun id ->
    lwt vbd,vbd_t = OS.Blkif.create id in
    lwt files = read_file_info vbd in
    printf "Read %d files\n%!" (Hashtbl.length files);
    return ()
  ) ids >>
  OS.Time.sleep 500. 

let _ = OS.Main.run (main ())
