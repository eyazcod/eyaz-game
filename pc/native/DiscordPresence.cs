// Discord local RPC framing: discord/discord-rpc/documentation/hard-mode.md
// Built with Windows .NET Framework; no tokens, login flow, or network calls.
using System;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

internal static class DiscordPresence {
    internal const string ApplicationId = "1560429281950175353";
    static readonly JavaScriptSerializer Json = new JavaScriptSerializer();
    static string statusPath;
    static Process parent;
    static long started;

    [STAThread]
    static void Main(string[] args) {
        try {
            int pid;
            if (args.Length != 2 || !int.TryParse(args[0], out pid)) return;
            parent = Process.GetProcessById(pid);
            statusPath = args[1];
            try { File.WriteAllText(statusPath,"",Encoding.UTF8); } catch {}
            started = (long)(DateTime.UtcNow-new DateTime(1970,1,1)).TotalSeconds;
            Status("starting");
            while (ParentAlive()) {
                bool connected = false;
                for (int index=0; index<10 && ParentAlive(); index++) {
                    using (var pipe = new NamedPipeClientStream(".","discord-ipc-"+index,PipeDirection.InOut,PipeOptions.Asynchronous)) {
                        try {
                            pipe.Connect(120);
                            connected = true;
                            Session(pipe,pid);
                        } catch (TimeoutException) {
                        } catch (Exception ex) {
                            Status("reconnecting: "+ex.GetType().Name);
                        }
                    }
                    if (connected) break;
                }
                if (!connected) Status("waiting_for_discord");
                for (int n=0;n<8 && ParentAlive();n++) Thread.Sleep(250);
            }
            Status("stopped");
        } catch (Exception ex) { Status("unavailable: "+ex.GetType().Name); }
    }

    static bool ParentAlive() {
        try { return parent != null && !parent.HasExited; } catch { return false; }
    }

    static void Status(string value) {
        try {
            if (!string.IsNullOrEmpty(statusPath)) {
                if (File.Exists(statusPath) && new FileInfo(statusPath).Length>65536) File.WriteAllText(statusPath,"",Encoding.UTF8);
                File.AppendAllText(statusPath,DateTime.UtcNow.ToString("o")+" "+value+Environment.NewLine,Encoding.UTF8);
            }
        } catch {}
    }

    internal static byte[] EncodeFrame(int opcode,string json) {
        byte[] body=Encoding.UTF8.GetBytes(json);
        byte[] frame=new byte[8+body.Length];
        Buffer.BlockCopy(BitConverter.GetBytes(opcode),0,frame,0,4);
        Buffer.BlockCopy(BitConverter.GetBytes(body.Length),0,frame,4,4);
        Buffer.BlockCopy(body,0,frame,8,body.Length);
        return frame;
    }

    internal static string Activity(int pid,long start,bool clear) {
        return Json.Serialize(new {cmd="SET_ACTIVITY",args=new {pid=pid,activity=clear ? null : new {type=0,timestamps=new {start=start},assets=new {large_image="eyaz_head",large_text="EYAZ — Crystal Archipelago"}}},nonce=Guid.NewGuid().ToString("N")});
    }

    static void Send(Stream pipe,int opcode,string json) {
        byte[] frame=EncodeFrame(opcode,json);
        // Discord requires each frame to be written in a single call.
        pipe.Write(frame,0,frame.Length); pipe.Flush();
    }

    static byte[] ReadExact(NamedPipeClientStream pipe,int size) {
        if (size<0 || size>1048576) throw new IOException("Invalid RPC frame length");
        byte[] data=new byte[size]; int offset=0;
        while (offset<size) {
            Task<int> pending=pipe.ReadAsync(data,offset,size-offset);
            while (!pending.Wait(250)) {
                if (!ParentAlive()) { pipe.Close(); return null; }
            }
            int count=pending.Result;
            if (count==0) throw new EndOfStreamException();
            offset+=count;
        }
        return data;
    }

    static void Session(NamedPipeClientStream pipe,int pid) {
        Send(pipe,0,Json.Serialize(new {v=1,client_id=ApplicationId}));
        Status("handshake_sent");
        try {
            while (ParentAlive()) {
                byte[] header=ReadExact(pipe,8);
                if (header==null) return;
                int opcode=BitConverter.ToInt32(header,0);
                byte[] body=ReadExact(pipe,BitConverter.ToInt32(header,4));
                if (body==null) return;
                string payload=Encoding.UTF8.GetString(body);
                if (opcode==3) { Send(pipe,4,payload); continue; }
                if (opcode==2) throw new IOException("Discord disconnected");
                if (opcode!=1) continue;
                var message=Json.DeserializeObject(payload) as System.Collections.Generic.Dictionary<string,object>;
                if (message==null) continue;
                object evt,cmd;
                message.TryGetValue("evt",out evt); message.TryGetValue("cmd",out cmd);
                if ((string)evt=="READY") {
                    Send(pipe,1,Activity(pid,started,false));
                    Status("activity_sent");
                } else if ((string)cmd=="SET_ACTIVITY" && (string)evt!="ERROR") {
                    Status("activity_confirmed");
                } else if ((string)evt=="ERROR") {
                    object details; message.TryGetValue("data",out details);
                    Status("discord_error: "+Json.Serialize(details));
                }
            }
        } finally {
            try { if (pipe.IsConnected) Send(pipe,1,Activity(pid,started,true)); } catch {}
        }
    }
}
