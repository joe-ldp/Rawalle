# cmd formatting:
# cmd[0] specifies command, later args are for cmd args
# cmd[0]: "ToWall" goes to wall scene
# cmd[0]: "Play" goes to main/playing scene, cmd[1] specifies instance to play
# cmd[0]: "Lock" shows or hides lock, cmd[1] specifies which lock, cmd[2] specifies to show or hide (1 = show, 0 = hide)
# cmd[0]: "GetImg" loads screenshot of instance into program memory, uses inst_num from last played instance
# cmd[0]: "SaveImg" saves current screenshot, cmd[1] specifies filename, cmd[2] specifies if run entered (1 = entered, 0 = did not)

from datetime import datetime
import shutil
from numpy import single
from obswebsocket import obsws, requests
from os.path import exists
import os
import csv
import sys
import urllib.request

def get_cmd(path):
    cmdFiles = []
    cmd = []
    for folder, subs, files in os.walk(path):
        for filename in files:
            cmdFiles.append(os.path.abspath(os.path.join(path, filename)))

    oldest_file = min(cmdFiles, key=os.path.getctime)
    while (cmd == []):
        try:
            with open(oldest_file) as cmd_file:
                csv_reader = csv.reader(cmd_file, delimiter=",")
                for row in csv_reader:
                    for value in row:
                        cmd.append(value)
        except:
            cmd = []

    os.remove(oldest_file)
    return cmd

def execute_cmd(cmd):
    if (len(cmd) > 0):
        match cmd[0]:
            case "ToWall":
                ws.call(requests.SetCurrentScene(f"{wall_scene}"))
            case "Play":
                global inst_num
                old_inst_num = inst_num
                inst_num = cmd[1]
                if (single_scene):
                    ws.call(requests.SetSceneItemRender(f"{instance_source_format}{inst_num}", True, f"{playing_scene}"))
                    if (inst_num != old_inst_num):
                        ws.call(requests.SetSceneItemRender(f"{instance_source_format}{old_inst_num}", False, f"{playing_scene}"))
                    ws.call(requests.SetCurrentScene(f"{playing_scene}"))
                else:
                    ws.call(requests.SetCurrentScene(f"{instance_scene_format}{inst_num}"))
            case "Lock":
                lock_num = cmd[1]
                render = True if int(cmd[2]) else False
                ws.call(requests.SetSceneItemRender(f"{lock_layer_format}{lock_num}", render, f"{wall_scene}"))
            case "GetImg":
                global img_data
                start = datetime.now().timestamp()
                while (datetime.now().timestamp() - start < 3):
                    if (single_scene):
                        layer_info_data = ws.call(requests.GetSceneItemProperties(f"{instance_source_format}{inst_num}", f"{playing_scene}")).datain
                    else:
                        layer_info_data = ws.call(requests.GetSceneItemProperties(f"{instance_source_format}{inst_num}", f"{instance_scene_format}{inst_num}")).datain
                    ratio = layer_info_data["width"] / layer_info_data["height"]
                    if (abs((16/9) - ratio) > 0.15):
                        print("Ratio " + str(ratio) + " exceeds allowed variance from 1.777..., instance is probably still wide, waiting")
                    else:
                        break
                img_data = ws.call(requests.TakeSourceScreenshot(f"{instance_source_format}{inst_num}", "png")).datain["img"]
            case "SaveImg":
                path = os.path.dirname(os.path.realpath(__file__)) + "\\..\\screenshots\\" + ("entered\\" if int(cmd[2]) else "unentered\\")
                filename = cmd[1]
                response = urllib.request.urlopen(img_data)
                with open(f"{path}{filename}.png", "wb") as f:
                    f.write(response.file.read())

print(sys.argv)
host = sys.argv[1]
port = int(sys.argv[2])
password = sys.argv[3]
lock_layer_format = sys.argv[4]
wall_scene = sys.argv[5]
instance_scene_format = sys.argv[6]
single_scene = True if sys.argv[7] == "True" else False
playing_scene = sys.argv[8]
instance_source_format = sys.argv[9]
num_instances = int(sys.argv[10])
inst_num = 0
img_data = ""

ws = obsws(host, port, password)
ws.connect()
scenes = ws.call(requests.GetSceneList())

for i in range(1, num_instances+1):
    print(i)
    ws.call(requests.SetSceneItemRender(f"{instance_source_format}{i}", False, f"{playing_scene}"))
    ws.call(requests.SetSceneItemRender(f"{lock_layer_format}{i}", False, f"{wall_scene}"))
    
try:
    ws.call(requests.SetCurrentScene(f"{wall_scene}"))
except:
    print("No wall scene found, not switching")

try:
    path = os.path.dirname(os.path.realpath(__file__)) + "\\"
    cmdsPath = path + "pyCmds"
    if (os.path.exists(cmdsPath)):
        shutil.rmtree(cmdsPath)
    os.mkdir(cmdsPath)
    print(f"Listening to {cmdsPath}...")
    while(exists(path + "runPy.tmp")):
        if (os.listdir(cmdsPath)):
            cmd = get_cmd(cmdsPath)
            print(cmd)
            execute_cmd(cmd)
except Exception as e:
    print(f"Error: {e}")

ws.disconnect()