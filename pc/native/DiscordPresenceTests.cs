using System;
using System.Text;
using System.Web.Script.Serialization;
using System.Collections.Generic;
class RpcTests {
    static int Main() {
        var json=new JavaScriptSerializer();
        byte[] frame=DiscordPresence.EncodeFrame(1,"{\"state\":\"إياز\"}");
        if(BitConverter.ToInt32(frame,0)!=1 || BitConverter.ToInt32(frame,4)!=frame.Length-8) throw new Exception("Invalid frame header");
        if(Encoding.UTF8.GetString(frame,8,frame.Length-8)!="{\"state\":\"إياز\"}") throw new Exception("UTF-8 framing failed");
        var command=json.Deserialize<Dictionary<string,object>>(DiscordPresence.Activity(123,456,false));
        var args=(Dictionary<string,object>)command["args"];
        var activity=(Dictionary<string,object>)args["activity"];
        if((int)args["pid"]!=123 || (int)activity["type"]!=0) throw new Exception("Incorrect game PID or activity");
        if((string)((Dictionary<string,object>)activity["assets"])["large_image"]!="eyaz_head") throw new Exception("Missing game artwork");
        var cleared=json.Deserialize<Dictionary<string,object>>(DiscordPresence.Activity(123,456,true));
        if(((Dictionary<string,object>)cleared["args"])["activity"]!=null) throw new Exception("Clear activity failed");
        Console.WriteLine("RPC_TESTS_OK: UTF-8, frame length, PID, Playing activity, clear command");
        return 0;
    }
}
