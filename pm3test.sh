#!/usr/bin/env bash

PM3PATH=$(dirname "$0")
cd "$PM3PATH" || exit 1

if [ "$1" == "client" ]; then
    shift
    TESTDEVICE=false
    TESTTOOLS=false
else
    TESTDEVICE=true
    TESTTOOLS=true
fi
if [ "$1" == "long" ]; then
    shift
    SLOWTESTS=true
else
    SLOWTESTS=false
fi

C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_NC='\033[0m' # No Color

# title, file name or file wildcard to check
function CheckFileExist() {

  if [ -f "$2" ]; then
    echo -e "$1 ${C_GREEN}[OK]${C_NC}"
    return 0
  fi

  if ls "$2" 1> /dev/null 2>&1; then
    echo -e "$1 ${C_GREEN}[OK]${C_NC}"
    return 0
  fi

  echo -e "$1 ${C_RED}[Fail]${C_NC}"
  return 1
}

# title, command line, check result, repeat several times if failed, ignore if fail
function CheckExecute() {

  if [ "$4" ]; then
    local RETRY="1 2 3 e"
  else
    local RETRY="e"
  fi

  for I in $RETRY
  do
    RES=$(eval "$2")
    if echo "$RES" | grep -q "$3"; then
      echo -e "$1 ${C_GREEN}[OK]${C_NC}"
      return 0
    fi
    if [ ! $I == "e" ]; then echo "retry $I"; fi
  done


  if [ "$5" ]; then
    echo -e "$1 ${C_YELLOW}[Ignored]${C_NC}"
    return 0
  fi

  echo -e "$1 ${C_RED}[Fail]${C_NC}"
  echo -e "Execution trace:\n$RES"
  return 1
}

echo -e "\n${C_BLUE}RRG/Iceman Proxmark3 test tool ${C_NC}\n"

echo -n "work directory: "
pwd
echo "client ${PM3BIN:="./client/proxmark3"}"

if [ "$TRAVIS_COMMIT" ]; then
  if [ "$TRAVIS_PULL_REQUEST" == "false" ]; then
    echo "Travis branch: $TRAVIS_BRANCH slug: $TRAVIS_REPO_SLUG commit: $TRAVIS_COMMIT"
  else
    echo "Travis pull request: $TRAVIS_PULL_REQUEST branch: $TRAVIS_BRANCH slug: $TRAVIS_PULL_REQUEST_SLUG commit: $TRAVIS_COMMIT"
  fi
fi

echo -n "git branch: "
git describe --all
echo -n "git sha: "
git rev-parse HEAD
echo ""

while true; do
  echo -e "\n${C_BLUE}Testing files:${C_NC}"
  if ! CheckFileExist "proxmark3 exists"               "$PM3BIN"; then break; fi
  if ! CheckFileExist "hardnested tables exists"       "./client/resources/hardnested_tables/bitflip_0_001_states.bin.z"; then break; fi
  if ! CheckFileExist "simmodule fw file exists"       "./tools/simmodule/sim011.bin"; then break; fi

  if $TESTDEVICE; then
    if ! CheckFileExist "arm image exists"             "./armsrc/obj/fullimage.elf"; then break; fi
    if ! CheckFileExist "bootrom exists"               "./bootrom/obj/bootrom.elf"; then break; fi
  fi

  echo -e "\n${C_BLUE}Testing basic help:${C_NC}"
  if ! CheckExecute "proxmark help"                    "$PM3BIN -h" "wait"; then break; fi
  if ! CheckExecute "proxmark help text ISO7816"       "$PM3BIN -t 2>&1" "ISO7816"; then break; fi
  if ! CheckExecute "proxmark help text hardnested"    "$PM3BIN -t 2>&1" "hardnested"; then break; fi

  echo -e "\n${C_BLUE}Testing data manipulation:${C_NC}"
  if ! CheckExecute "reveng readline test"    "$PM3BIN -c 'reveng -h;reveng -D'" "CRC-64/GO-ISO"; then break; fi
  if ! CheckExecute "reveng -g test"          "$PM3BIN -c 'reveng -g abda202c'" "CRC-16/ISO-IEC-14443-3-A"; then break; fi
  if ! CheckExecute "reveng -w test"          "$PM3BIN -c 'reveng -w 8 -s 01020304e3 010204039d'" "CRC-8/SMBUS"; then break; fi
  if ! CheckExecute "mfu pwdgen test"         "$PM3BIN -c 'hf mfu pwdgen t'" "Selftest OK"; then break; fi
  if ! CheckExecute "trace load/list 14a"     "$PM3BIN -c 'trace load traces/hf_mfu.trace; trace list 1;'" "READBLOCK(8)"; then break; fi
  if ! CheckExecute "trace load/list x"       "$PM3BIN -c 'trace load traces/hf_mfu.trace; trace list x 1;'" "0.0101840425"; then break; fi

  echo -e "\n${C_BLUE}Testing LF:${C_NC}"
  if ! CheckExecute "lf EM4x05 test"        "$PM3BIN -c 'data load traces/em4x05.pm3;lf search 1'" "FDX-B ID found"; then break; fi
  if ! CheckExecute "lf EM410x test"        "$PM3BIN -c 'data load traces/EM4102-1.pm3;lf search 1'" "EM410x ID found"; then break; fi
  if ! CheckExecute "lf VISA2000 test"      "$PM3BIN -c 'data load traces/visa2000.pm3;lf search 1'" "Visa2000 ID found"; then break; fi
  if ! CheckExecute "lf AWID test"          "$PM3BIN -c 'data load traces/AWID-15-259.pm3;lf search 1'" "AWID ID found"; then break; fi
  if ! CheckExecute "lf SECURAKEY test"     "$PM3BIN -c 'data load traces/securakey-64169.pm3;lf search 1 '" "Securakey ID found"; then break; fi
  if ! CheckExecute "lf NEXWATCH test"      "$PM3BIN -c 'data load traces/quadrakey-521512301.pm3;lf search 1 '" "NexWatch ID found"; then break; fi
  if ! CheckExecute "lf KERI test"          "$PM3BIN -c 'data load traces/keri.pm3;lf search 1'" "Pyramid ID found"; then break; fi
  if ! CheckExecute "lf HID Prox test"      "$PM3BIN -c 'data load traces/hid-proxCardII-05512-11432784-1.pm3;lf search 1'" "HID Prox ID found"; then break; fi
  if ! CheckExecute "lf PARADOX test"       "$PM3BIN -c 'data load traces/Paradox-96_40426-APJN08.pm3;lf search 1'" "Paradox ID found"; then break; fi
  if ! CheckExecute "lf PAC test"           "$PM3BIN -c 'data load traces/pac-8E4C058E.pm3;lf search 1'" "PAC/Stanley ID found"; then break; fi
  if ! CheckExecute "lf VIKING test"        "$PM3BIN -c 'data load traces/Transit999-best.pm3;lf search 1'" "Viking ID found"; then break; fi
  if ! CheckExecute "lf FDX-B test"         "$PM3BIN -c 'data load traces/homeagain1600.pm3;lf search 1'" "FDX-B ID found"; then break; fi
  if ! CheckExecute "lf INDALA test"        "$PM3BIN -c 'data load traces/indala-504278295.pm3;lf search 1'" "Indala ID found"; then break; fi
  if ! CheckExecute "lf FDX/BioThermo test" "$PM3BIN -c 'data load traces/lf_fdx_biothermo.pm3; lf fdx demo'" "95.2 F / 35.1 C"; then break; fi


  echo -e "\n${C_BLUE}Testing HF:${C_NC}"
  if ! CheckExecute "hf mf offline text"               "$PM3BIN -c 'hf mf'" "at_enc"; then break; fi
  if $SLOWTESTS; then
    if ! CheckExecute "hf mf hardnested test"          "$PM3BIN -c 'hf mf hardnested t 1 000000000000'" "found:" "repeat" "ignore"; then break; fi
    if ! CheckExecute "hf iclass test"                 "$PM3BIN -c 'hf iclass loclass t l'" "verified ok"; then break; fi
    if ! CheckExecute "emv test"                       "$PM3BIN -c 'emv test -l'" "Test(s) \[ OK"; then break; fi
  else
    if ! CheckExecute "hf iclass test"                 "$PM3BIN -c 'hf iclass loclass t'" "key diversification (ok)"; then break; fi
    if ! CheckExecute "emv test"                       "$PM3BIN -c 'emv test'" "Test(s) \[ OK"; then break; fi
  fi

  if $TESTTOOLS; then
    echo -e "\n${C_BLUE}Testing tools:${C_NC}"
    # Need a decent example for mfkey32...
    if ! CheckExecute "mfkey32v2 test"                   "tools/mfkey/mfkey32v2 12345678 1AD8DF2B 1D316024 620EF048 30D6CB07 C52077E2 837AC61A" "Found Key: \[a0a1a2a3a4a5\]"; then break; fi
    if ! CheckExecute "mfkey64 test"                     "tools/mfkey/mfkey64 9c599b32 82a4166c a1e458ce 6eea41e0 5cadf439" "Found Key: \[ffffffffffff\]"; then break; fi
    if ! CheckExecute "mfkey64 long trace test"          "tools/mfkey/./mfkey64 14579f69 ce844261 f8049ccb 0525c84f 9431cc40 7093df99 9972428ce2e8523f456b99c831e769dced09 8ca6827b ab797fd369e8b93a86776b40dae3ef686efd c3c381ba 49e2c9def4868d1777670e584c27230286f4 fbdcd7c1 4abd964b07d3563aa066ed0a2eac7f6312bf 9f9149ea" "Found Key: \[091e639cb715\]"; then break; fi
    if ! CheckExecute "nonce2key test"                   "tools/nonce2key/nonce2key e9cadd9c a8bf4a12 a020a8285858b090 050f010607060e07 5693be6c00000000" "key recovered: fc00018778f7"; then break; fi
    if ! CheckExecute "xorcheck test"                    "tools/xorcheck.py 04 00 80 64 ba" "final LRC XOR byte value: 5A"; then break; fi
    if ! CheckExecute "findbits test"                    "tools/findbits.py 73 0110010101110011" "Match at bit 9: 011001010"; then break; fi
    if ! CheckExecute "findbits_test test"               "tools/findbits_test.py 2>&1" "OK"; then break; fi
    if ! CheckExecute "pm3_eml_mfd test"                 "tools/pm3_eml_mfd_test.py 2>&1" "OK"; then break; fi
    if $SLOWTESTS; then
      if ! CheckExecute "mf_nonce_brute test"              "tools/mf_nonce_brute/mf_nonce_brute 9c599b32 5a920d85 1011 98d76b77 d6c6e870 0000 ca7e0b63 0111 3e709c8a" "Key.*: \[ffffffffffff\]"; then break; fi
    fi
  fi

  echo -e "\n${C_GREEN}Tests [OK]${C_NC}\n"
  exit 0
done

echo -e "\n${C_RED}Tests [FAIL]${C_NC}\n"
exit 1
