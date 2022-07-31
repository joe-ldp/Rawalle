# v1.2.0

# cmd formatting:
# cmd[0] specifies command, later args are for cmd args
# cmd[0]: "ToWall" goes to wall scene
# cmd[0]: "Play" goes to main/playing scene, cmd[1] specifies instance to play
# cmd[0]: "Lock" shows or hides lock, cmd[1] specifies which lock, cmd[2] specifies to show or hide (1 = show, 0 = hide)
# cmd[0]: "GetImg" loads screenshot of instance into program memory, uses inst_num from last played instance
# cmd[0]: "SaveImg" saves current screenshot, cmd[1] specifies filename, cmd[2] specifies if run entered (1 = entered, 0 = did not)

from datetime import datetime
import shutil
from obswebsocket import obsws, requests
from os.path import exists
import os
import csv
import urllib.request
import time
import logging
import obsSettings as settings

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
        global inst_num
        instance_layer_name = settings.instance_source_format.replace("*", str(inst_num))
        match cmd[0]:
            case "ToWall":
                ws.call(requests.SetCurrentScene(f"{settings.wall_scene}"))
            case "Play":
                old_inst_num = inst_num
                inst_num = cmd[1]
                if (settings.single_scene):
                    ws.call(requests.SetSceneItemRender(f"{instance_layer_name}", True, f"{settings.playing_scene}"))
                    if (inst_num != old_inst_num):
                        ws.call(requests.SetSceneItemRender(settings.instance_source_format.replace("*", old_inst_num), False, f"{settings.playing_scene}"))
                    ws.call(requests.SetCurrentScene(f"{settings.playing_scene}"))
                else:
                    ws.call(requests.SetCurrentScene(settings.instance_scene_format.replace("*", inst_num)))
            case "Lock":
                lock_num = cmd[1]
                render = True if int(cmd[2]) else False
                ws.call(requests.SetSceneItemRender(settings.lock_layer_format.replace("*", lock_num), render, f"{settings.wall_scene}"))
            case "GetImg":
                global img_data
                start = datetime.now().timestamp()
                while (datetime.now().timestamp() - start < 3):
                    if (settings.single_scene):
                        layer_info_data = ws.call(requests.GetSceneItemProperties(f"{instance_layer_name}", f"{settings.playing_scene}")).datain
                    else:
                        layer_info_data = ws.call(requests.GetSceneItemProperties(f"{instance_layer_name}", settings.instance_scene_format.replace("*", inst_num))).datain
                    h = layer_info_data["sourceHeight"]
                    wide_height = settings.screen_height / settings.width_multiplier
                    print(layer_info_data)
                    if (h <= wide_height):
                        print(f"Found height {h}, instance is still wide, waiting")
                    else:
                        print (f"Found height {h}, taking screenshot")
                        break
                img_data = ws.call(requests.TakeSourceScreenshot(f"{instance_layer_name}", "png")).datain["img"]
            case "SaveImg":
                path = os.path.dirname(os.path.realpath(__file__)) + "\\..\\screenshots\\" + ("entered\\" if int(cmd[2]) else "unentered\\")
                filename = cmd[1]
                response = urllib.request.urlopen(img_data)
                with open(f"{path}{filename}.png", "wb") as f:
                    f.write(response.file.read())

logging.basicConfig(filename="obs_log.log")

try:
    inst_num = 0
    img_data = ""

    ws = obsws(settings.host, settings.port, settings.password)
    ws.connect()
except Exception as e:
    print(e)
    logging.error(e)

for i in range(1, settings.num_instances+1):
    print(f"Setting up instance {i}")
    try:
        source_layer_name = settings.instance_source_format.replace("*", str(i))
        ws.call(requests.SetSceneItemRender(f"{source_layer_name}", False, f"{settings.playing_scene}"))
        lock_layer_name = settings.lock_layer_format.replace("*", str(i))
        ws.call(requests.SetSceneItemRender(f"{lock_layer_name}", False, f"{settings.wall_scene}"))
    except:
        msg = "Some setup didn't complete (it's probably ok, just not using some features)."
        print(msg)
        logging.debug(msg)
    
try:
    ws.call(requests.SetCurrentScene(f"{settings.wall_scene}"))
except:
    msg = "No wall scene found, not switching"
    print(msg)
    logging.debug(msg)


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
        time.sleep(0.2)
except Exception as e:
    print(f"Error: {e}")
    logging.error(msg)

ws.disconnect()