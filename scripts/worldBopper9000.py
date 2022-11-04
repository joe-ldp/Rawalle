# v1.3.0

# Code taken and adapted from https://github.com/grahamlyons/delete-old-files

import logging
import glob, sys, shutil, os
from operator import itemgetter

logging.basicConfig(
    filename="worldBopper.log",
    format='%(asctime)s %(levelname)-8s %(message)s',
    level=logging.INFO,
    datefmt='%Y-%m-%d %H:%M:%S')

bopped = 0

def sort_files_by_last_modified(files):
    file_data = {}
    for fname in files:
        if "New World" in fname or "Speedrun #" in fname:
            file_data[fname] = os.stat(fname).st_mtime
            logging.log(logging.INFO, "Found world: " + fname)

    file_data = sorted(file_data.items(), key = itemgetter(1))
    return file_data

def delete_oldest_files(sorted_files):
    global bopped
    for x in range(0, len(sorted_files) - 10):
        shutil.rmtree(sorted_files[x][0])
        logging.log(logging.INFO, "Bopped world: " + sorted_files[x][0])
        bopped += 1

try:
    file_paths = ""
    if (sys.argv[1][-1] == '\\' or sys.argv[1][-1] == "/"):
        file_paths = glob.glob(sys.argv[1] + "saves/*")
    else:
        file_paths = glob.glob(sys.argv[1] + "/saves/*")
    sorted_files = sort_files_by_last_modified(file_paths)

    delete_oldest_files(sorted_files)
    if (bopped > 0):
        logging.log(logging.INFO, f"Bopped {bopped} worlds successfully")
except Exception as e:
    print(e)
    logging.error(e)