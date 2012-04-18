(*
 * Copyright (c) 2005-2011 Anil Madhavapeddy <anil@recoil.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Lwt 
open Printf

let port = 53

let get_file filename = 
  OS.Devices.with_kv_ro "fs" (fun kv_ro ->
    match_lwt kv_ro#read filename with
      | None -> return None
      | Some k
        -> Bitstring_stream.string_of_stream k >|= (fun x -> Some x)
  )

let main () =
  Log.info "Deens" "starting server, port %d" port;
  let zonebuf () = 
    match_lwt get_file "zones.db" with
      | Some s -> return s
      | None   -> return ""
  in
  Net.Manager.create (fun mgr interface id ->
    let src = None, port in
    lwt zb = zonebuf () in
    Dns.Server.listen zb mgr src
  )

let main () =
  Net.Manager.create (fun mgr interface id ->
     let ip = Net.Nettypes.(
      (ipv4_addr_of_tuple (10l,0l,0l,2l),
       ipv4_addr_of_tuple (255l,255l,255l,0l),
       [ipv4_addr_of_tuple (10l,0l,0l,1l)]
      )) in
    lwt () = Net.Manager.configure interface (`IPv4 ip) in
  
    let src = None, port in
    let zonefile = "zones.db" in
    lwt zb = get_file zonefile in
    match zb with
    |None -> fail (Failure "no zone")
    |Some zonebuf ->  Dns.Server.listen ~mode:`none ~zonebuf mgr src
  )
