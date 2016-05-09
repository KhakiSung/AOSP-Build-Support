# AOSP-Build-Support version 1.0.4

Run
  1. build Android Open Source Project(AOSP) code 
  2. binary compare libs
  3. push to device

with in one command

### Options:
    BUILD_COMMAND           - mm, mma, mmm PATH, mmma PATH  
    -jN                     - make job num. default -j4  
    -a, --autopush          - Auto push diff libs without asking user (skip lib name containing "test")
    -s, --snapshot          - Use current libs in dir PRODUCT_OUT/system as snapshot for compare standard
    -l, --lib=SNAPSHOT_DIR  - Where compare libs standard put, default is PRODUCT_OUT/backup
                              Support relative/absolute path. Root dir is PRODUCT_OUT/
    -v, --verbose           - more log to stdout

### Recommand install step:
  1. add alias to `~/.bashrc`  
        `alias bs='. buildSupport.sh'`
  2. copy file `buildSupport.sh` to `usr/local/bin`

### Usage Example:
  (in one of aosp project)`$ bs mm -s`

##### this command will do:  
  1. copy libs (`-s`)
  2. run mm (build code)
  3. binary compare between build output and copies
  4. ask user to make sure these diff lib is user need (If don't want confirm, add `-a`)  
  (Diff libs are default select, others are unselected which are build output but binary compare same with copies)
  5. push libs to device

##### testing environment:
- ubuntu 14.04 LTS
- gnome terminal 3.6.2