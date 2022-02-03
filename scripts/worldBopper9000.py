import glob
import sys
import shutil

files = glob.glob(sys.argv[1] + '/saves/*')
print(files)
for f in files:
    try:
        if "New World" in f or "Speedrun #" in f:
            shutil.rmtree(f)
    except:
        # well fuck
        b = 7 # only real ones know