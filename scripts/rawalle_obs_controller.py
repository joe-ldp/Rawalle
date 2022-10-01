# v1.3.0

# cmd formatting:
# cmd[0] specifies command, later args are for cmd args
# cmd[0]: "ToWall" goes to wall scene
# cmd[0]: "Play" goes to main/playing scene, cmd[1] specifies instance to play
# cmd[0]: "Lock" shows or hides lock, cmd[1] specifies which lock, cmd[2] specifies to show or hide (1 = show, 0 = hide)

import obsSettings as settings
import obspython as S
import importlib
import logging
import shutil
import csv
import os

logging.basicConfig(
    filename=os.path.dirname(os.path.realpath(__file__)) + "\obs_log.log",
    format='%(asctime)s %(levelname)-8s %(message)s',
    level=logging.INFO,
    datefmt='%Y-%m-%d %H:%M:%S')

version = "v1.3.0"

def script_update(settings):
    script_init()

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
    try:
        if (cmd[0] == "ToWall"):
            wall_scene = S.obs_scene_get_source(S.obs_get_scene_by_name(settings.wall_scene))
            S.obs_frontend_set_current_scene(wall_scene)
            S.obs_source_release(wall_scene)
        elif (cmd[0] == "Play"):
            inst_num = cmd[1]
            instance_scene = S.obs_scene_get_source(S.obs_get_scene_by_name(settings.instance_scene_format.replace("*", str(inst_num))))
            S.obs_frontend_set_current_scene(instance_scene)
            S.obs_source_release(instance_scene)
        elif (cmd[0] == "Lock"):
            lock_num = cmd[1]
            render = True if int(cmd[2]) else False
            wall_scene = S.obs_scene_get_source(S.obs_get_scene_by_name(settings.wall_scene))
            lock_source = S.obs_scene_find_source(S.obs_scene_from_source(wall_scene), settings.lock_layer_format.replace("*", str(lock_num)))
            S.obs_sceneitem_set_visible(lock_source, render)
            S.obs_source_release(lock_source)
            S.obs_source_release(wall_scene)
        elif (cmd[0] == "Reload"):
            script_init()
    except Exception as e:
        print(f"Error: {e}")
        logging.error(e)

def execute_latest():
    global cmdsPath
    try:
        if (os.listdir(cmdsPath)):
            cmd = get_cmd(cmdsPath)
            print(cmd)
            execute_cmd(cmd)
    except Exception as e:
        print(f"Error: {e}")
        logging.error(e)

def script_description():
    return f"Ravalle's OBS Script for <a href=https://github.com/joe-ldp/rawalle/releases/tag/{version}>Rawalle {version}</a></h3>"

def script_init():
    importlib.reload(settings)
    global cmdsPath
    try:
        execute_cmd(["ToWall"])
    except Exception as e:
        print(f"Error: {e}")
        logging.error(e)

    for i in range(1, settings.num_instances+1):
        print(f"Setting up instance {i}")
        logging.info(f"Setting up instance {i}")
        try:
            execute_cmd(["Lock", i, 0])
        except Exception as e:
            print(f"Error: {e}")
            logging.error(e)

    path = os.path.dirname(os.path.realpath(__file__)) + "\\"
    cmdsPath = path + "pyCmds\\"

    if (os.path.exists(cmdsPath)):
        shutil.rmtree(cmdsPath)
    os.mkdir(cmdsPath)

    print(f"Listening to {cmdsPath}...")
    logging.info(f"Listening to {cmdsPath}...")

    S.timer_remove(execute_latest)
    S.timer_add(execute_latest, 30)