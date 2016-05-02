# AOSP-Build-Support version 1.0.3

Run
  1. build Android Open Source Project(AOSP) code 
  2. binary compare libs
  3. push to device

with in one command

### Options:
    BUILD_COMMAND           - mm, mma, mmm PATH, mmma PATH  
    -jN                     - make job num. default -j4  
    -a, --autopush          - Auto push diff libs without asking user
    -s, --snapshot          - Use current libs in dir PRODUCT_OUT/system as snapshot for compare standard
    -l, --lib=SNAPSHOT_DIR  - Where compare libs standard put, default is PRODUCT_OUT/backup
                              Support relative/absolute path. Root dir is PRODUCT_OUT/

### Recommand install step:
  1. add alias to `~/.bashrc`  
        `alias bs='. buildSupport.sh'`
  2. copy file `buildSupport.sh` to `usr/local/bin`

### Usage Example:
  (in one of aosp project)`$ bs mm -s`

##### this command will do:  
  1. copy libs 
  2. build code
  3. binary compare between build output and copies
  4. ask user which file need to push into devices