# v1.0.0-beta

# Code taken and adapted from https://github.com/grahamlyons/delete-old-files

import glob, sys, shutil, os
from operator import itemgetter

def sort_files_by_last_modified(files):
    file_data = {}
    for fname in files:
        if "New World" in fname or "Speedrun #" in fname:
            file_data[fname] = os.stat(fname).st_mtime

    file_data = sorted(file_data.items(), key = itemgetter(1))
    return file_data

def delete_oldest_files(sorted_files):
    for x in range(0, len(sorted_files) - 10):
        shutil.rmtree(sorted_files[x][0])

file_paths = glob.glob(sys.argv[1] + "/saves/*")
sorted_files = sort_files_by_last_modified(file_paths)

delete_oldest_files(sorted_files)