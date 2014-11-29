#!/bin/bash


# ESP IoT SDK
ESP_SDK_PKG="esp_iot_sdk_v0.9.3_14_11_21.zip"
ESP_SDK_URL="http://bbs.espressif.com/download/file.php?id=72"

# ESP IoT SDK Patch
ESP_SDK_PATCH_PKG="esp_iot_sdk_v0.9.3_14_11_21_patch1.zip"
ESP_SDK_PATCH_URL="http://bbs.espressif.com/download/file.php?id=73"

# Project directories
WORKDIR=`pwd`
LOG_FILE=$WORKDIR/build.log
DOWNLOAD_DIR=$WORKDIR/download
RELEASE_DIR=$WORKDIR/release
TOOLCHAIN_DIR=$RELEASE_DIR/xtensa-lx106-elf


# Print Message function
# Usage: print_msg [status_flag] "message"
#        status_flag - "I" -> "INFO", "W" -> "WARNING", "E" -> "ERROR"
function print_msg()
{
  local TIME=`date +%X`
  local MARK="INFO:"
  local MESSAGE=$1

  if [ "$#" -gt "1" ]; then
    case $1 in
      "E") MARK="ERROR:";;
      "W") MARK="WARNING:";;
      *) ;;
    esac

    MESSAGE=$2
  fi

  echo -e "[$TIME] $MARK ${MESSAGE}"
  echo -e "[$TIME] $MARK ${MESSAGE}" >> $LOG_FILE
}


# Extract package archive function
# Usage: extract <pkg_path> <out_dir> 
function extract()
{
  local PKG_PATH="$1"
  local PKG_EXT=${PKG_PATH##*.}
  local PKG_ODIR="$2"

  if [ ! -f ${PKG_PATH} ]; then
    print_msg "E" "Package: $PKG_PATH doesn't exist"
    exit 1
  fi

  # Parse arguments
  case $PKG_EXT in
    gz)  tar -xzf ${PKG_PATH} -C ${PKG_ODIR};;
    bz2) tar -xjf ${PKG_PATH} -C ${PKG_ODIR};;
    zip) unzip -o -q ${PKG_PATH} -d ${PKG_ODIR};;
    7z)  7z x ${PKG_PATH} -o${PKG_ODIR};;
    *) print_msg "E" "Unsupported archive: $PKG_EXT"; exit 1 ;;
  esac

  if [ $? -ne 0 ]; then
    print_msg "E" "Extraction failed, exit ! \n"
    rm -rfd ${PKG_ODIR}
    exit 1
  fi
}


# Prepare Directories function
function initialize_dirs()
{
  print_msg "Install Directories"

  [ ! -d ${DOWNLOAD_DIR} ] && mkdir ${DOWNLOAD_DIR}

  if [ -d ${RELEASE_DIR} ]; then
    #if exist release dir, remove it content
    rm -rfd ${RELEASE_DIR}
  fi

  mkdir -p ${RELEASE_DIR}

  print_msg "Successfully Done \n"
}


# Download Package function
# Usage: download_package <package_url>
function download_package()
{
  local PKG_URL="$1"
  local PKG_NAME="${PKG_URL##*/}"
  local PKG_ARGS=""
  local PKG_PARAMS=""

  # shift to next parameter
  shift

  #[ "$DEBUG_LEVEL" == "0" ] && PKG_ARGS="-q " 

  # Parse arguments
  while [[ $# > 0 ]]; do
    param="$1" && shift
    case $param in
      -n) PKG_NAME="$1" && shift ;;
      -c) PKG_ARGS+="--no-cookies --no-check-certificate --header"; PKG_PARAMS="$1"; shift;;
      *)  print_msg "E" "Unrecognized parameter: $param"; exit 1;;
    esac
  done

  if [ ! -f ${DOWNLOAD_DIR}/${PKG_NAME} ]; then

    print_msg "Downloading package: ${PKG_NAME} \n"

    if [ "${PKG_PARAMS}" != "" ]; then
      wget ${PKG_ARGS} "${PKG_PARAMS}" -O ${DOWNLOAD_DIR}/${PKG_NAME} ${PKG_URL}
    else
      wget ${PKG_ARGS} -O ${DOWNLOAD_DIR}/${PKG_NAME} ${PKG_URL}
    fi

    if [ $? -ne 0 ]; then
      print_msg "E" "Download failed, exit ! \n"
      rm -f ${DOWNLOAD_DIR}/${PKG_NAME}
      exit 1
    fi

    print_msg "Successfully Done \n"
  fi
}





#####################################################################################
# MAIN
#####################################################################################
echo "" > $LOG_FILE

print_msg "You cloned without --recursive, fetching submodules for you."
git submodule update --init --recursive

# Initialization
initialize_dirs

# Download Packages
download_package "$ESP_SDK_URL" -n "$ESP_SDK_PKG"
download_package "$ESP_SDK_PATCH_URL" -n "$ESP_SDK_PATCH_PKG"

print_msg "Build ESP SDK"
extract "$DOWNLOAD_DIR/$ESP_SDK_PKG" "$RELEASE_DIR"
extract "$DOWNLOAD_DIR/$ESP_SDK_PATCH_PKG" "$RELEASE_DIR"
mv $RELEASE_DIR/License $RELEASE_DIR/*/

mkdir $TOOLCHAIN_DIR


# Build ESP Toolchain
print_msg "Build ESP Toolchain"
cd crosstool-NG
./bootstrap && ./configure --prefix=`pwd` && make && make install
if [ $? -ne 0 ]; then
  print_msg "E" "Build ESP Toolchain failed, exit ! \n"
  cd $WORKDIR
  exit 1
fi

./ct-ng xtensa-lx106-elf
cp .config .config.bak
sed -r -i s%CT_PREFIX_DIR=.*%CT_PREFIX_DIR=\"${TOOLCHAIN_DIR}\"% .config
sed -r -i s%CT_INSTALL_DIR_RO=y%\#CT_INSTALL_DIR_RO=y% .config
echo "CT_STATIC_TOOLCHAIN=y" >> .config
echo "CT_LIBC_NEWLIB_ENABLE_TARGET_OPTSPACE=y" >> .config
./ct-ng build
if [ $? -ne 0 ]; then
  print_msg "E" "Build ESP Toolchain failed, exit ! \n"
  cd $WORKDIR
  exit 1
fi

cd $WORKDIR


# Build ESP hal
print_msg "Build ESP hal"
cd lx106-hal
autoreconf -i
PATH=$TOOLCHAIN_DIR/bin:$PATH
./configure --host=xtensa-lx106-elf --prefix=$TOOLCHAIN_DIR/xtensa-lx106-elf/sysroot/usr && make && make install
if [ $? -ne 0 ]; then
  print_msg "E" "Build ESP hal failed, exit ! \n"
  cd $WORKDIR
  exit 1
fi

cd $WORKDIR


# Create irom version of libc...
print_msg "Create irom version of libc..."
$TOOLCHAIN_DIR/bin/xtensa-lx106-elf-objcopy --rename-section .text=.irom0.text \
                                            --rename-section .literal=.irom0.literal \
                                            $TOOLCHAIN_DIR/xtensa-lx106-elf/sysroot/lib/libc.a \
                                            $TOOLCHAIN_DIR/xtensa-lx106-elf/sysroot/lib/libcirom.a
if [ $? -ne 0 ]; then
  print_msg "E" "Creating irom failed, exit ! \n"
  cd $WORKDIR
  exit 1
fi


# Install esptool.py
print_msg "Install esptool.py"
cp esptool/esptool.py $TOOLCHAIN_DIR/bin/


# Build esptool-ck
print_msg "Build esptool-ck"
cd esptool-ck
make
if [ $? -ne 0 ]; then
  print_msg "E" "Building esptool-ck failed, exit ! \n"
  cd $WORKDIR
  exit 1
fi

cp esptool $TOOLCHAIN_DIR/bin/
cd $WORKDIR


print_msg "Successfully Done \n"

exit 0

