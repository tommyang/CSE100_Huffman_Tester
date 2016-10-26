#!/usr/bin/env bash
#### Description: UCSD CSE100 Fall 2016 PA3 Self-Tester for Students.
#### Usage:
#### 1. In the directory that contains the script, run `chmod u+x ty_tester.sh` so that it is executable.
####   * See [chmod](https://en.wikipedia.org/wiki/Chmod) on Wikipedia.
#### 2. Run `./ty_tester.sh -r` on ieng6 or `./ty_tester.sh` on machines that cannot run `refcompress`

set -o nounset

# Text
# These are used for colored command line output
# See https://en.wikipedia.org/wiki/Tput
TXT_RESET="$(tput sgr 0 2> /dev/null)"
TXT_RED="$(tput setaf 1 2> /dev/null)"
TXT_GREEN="$(tput setaf 2 2> /dev/null)"
TXT_YELLOW="$(tput setaf 3 2> /dev/null)"
TXT_CYAN="$(tput setaf 6 2> /dev/null)"

# Variables
INPUT_DIR="pa3_input_files"
YOUR_CMP="ty_test_your_cmp.tmp"
YOUR_UNCMP="ty_test_your_uncmp.tmp"
REF_CMP="ty_test_ref_cmp.tmp"
RAND_TXT="ty_large_random_input.txt"
RAND_BIN="ty_large_random_input.bin"
RAND_SIZE=$(( 5 * 2**20 )) # 5 MiB

# `mktemp -d` creates a temporary directory to store the generated test files
TMP_DIR="$(mktemp -d)"

# This function takes in a size argument and generates random text & binary files of that size in byte
# Using `openssl rand` is faster than using `/dev/urandom`, at least on ieng6
# See https://en.wikipedia.org/wiki/OpenSSL https://en.wikipedia.org/wiki//dev/random
generate_random_input_files() {
  local input_file_size="$1" # the size argument
  if [[ -z ${input_file_size} ]]; then
    echo "generate_random_input_files: No size was specified. Exiting. ";
    exit 1
  fi
  echo -ne "Generating random input text & binary files... "
  # Base64 is used to produce the random text file, see: https://en.wikipedia.org/wiki/Base64
  # The "* 3 / 4" part roughly accounts for Base64 overhead so that the output is of the correct size
  openssl rand -out "${INPUT_DIR}/${RAND_TXT}" -base64 $(( input_file_size * 3 / 4 ))
  openssl rand -out "${INPUT_DIR}/${RAND_BIN}" "${input_file_size}"
  echo "Done. "
}

# This function uses stat to get the file sizes of your compressed version and the reference compressed version
compression_ratio_test() {
  local ref_cmp_filesize
  local your_cmp_filesize
  # This if statement is to test whether the machine has GNU `stat` or BSD `stat` since their flags are different
  # The if condition works because BSD `stat` does not have the `--version` flag so the return code will tell
  #
  # In this version of the script, `compression_ratio_test` is run only if you pass in the "-r" flag.
  # This is because the `refcompress` executable provided to you is compiled on ieng6 and will not run on other platforms.
  # So this GNU/BSD `stat` detection is not that useful for you since we know ieng6 has GNU `stat`.
  # (I do run `refcompress` on a certain platform that has BSD `stat` :-P)
  # See https://en.wikipedia.org/wiki/GNU_toolchain & https://wiki.freebsd.org/BSDToolchain
  if stat --version 1>/dev/null 2>&1; then
    # GNU `stat`
    ref_cmp_filesize="$(stat -c%s "${TMP_DIR}/${REF_CMP}")"
    your_cmp_filesize="$(stat -c%s "${TMP_DIR}/${YOUR_CMP}")"
  else
    # BSD `stat`
    ref_cmp_filesize="$(stat -f%z "${TMP_DIR}/${REF_CMP}")"
    your_cmp_filesize="$(stat -f%z "${TMP_DIR}/${YOUR_CMP}")"
  fi
  # The actual comparison, `-gt` means greater than
  if [[ ${ref_cmp_filesize} -gt ${your_cmp_filesize} ]]; then
    echo -e "[${TXT_GREEN}PASSED${TXT_RESET}]"
  else
    echo -e "[${TXT_YELLOW}ACCURATE${TXT_RESET}]"
    echo -e "${TXT_YELLOW}Reference compressed size: ${ref_cmp_filesize}. Your compressed size is ${your_cmp_filesize}. ${TXT_RESET}"
  fi
}

# This function removes the generated files
cleanup () {
  rm "${INPUT_DIR}/${RAND_TXT}" "${INPUT_DIR}/${RAND_BIN}" 1>/dev/null 2>&1
  rm -rf "${TMP_DIR}" 1>/dev/null 2>&1
  echo "Temporary files generated by the tests deleted. "
  echo -e "${TXT_YELLOW}WARNING: THIS SCRIPT IS PROVIDED FOR YOUR CONVENIENCE ONLY. ${TXT_RESET}"
  echo -e "${TXT_YELLOW}IT IS PROVIDED WITHOUT ANY GUARANTEE. ${TXT_RESET}"
  echo -e "${TXT_YELLOW}YOU ARE RESPONSIBLE FOR MAKING SURE THAT YOUR CODE WORKS CORRECTLY. ${TXT_RESET}"
}
trap cleanup EXIT # trap is a nice feature. Upon EXIT, this cleanup function is run

## The script starts here ##

echo -e "${TXT_CYAN}UCSD CSE100 Huffman Tester${TXT_RESET}"

# check command line parameters
if [ $# -eq 0 ]; then
  ENABLE_RATIO_TEST=false
  echo -e "${TXT_CYAN}Compression Ratio Test Not Enabled${TXT_RESET}"
elif [[ $# -eq 1 && $1 == "-r" ]]; then
  ENABLE_RATIO_TEST=true
  echo -e "${TXT_CYAN}Compression Ratio Test Enabled${TXT_RESET}"
else
  echo -e "$0: error: invalid command option given"
  echo "Usage: ty_tester.sh [-r]"
  echo "Please read the README and this script for details. "
  exit 1
fi

# Use `make` to compile your code, check return code for failure
if ! make 1>/dev/null 2>&1; then
    echo -e "${TXT_RED}Failed to compile your code using make. ${TXT_RESET} Tests not run. "
    exit 1 # unsuccessful
fi
echo -e "Compiled your code successfully using make. "

# Generates a random binary input file and a random text input file for testing
generate_random_input_files ${RAND_SIZE}

# Loop through all the input files found in the input file directory
for input_file in "${INPUT_DIR}"/*; do
  echo -ne "Testing \"${input_file}\"... \t "
  # Generate your compressed and uncompressed version of input_file
  ./compress "${input_file}" "${TMP_DIR}/${YOUR_CMP}" 1>/dev/null 2>&1
  ./uncompress "${TMP_DIR}/${YOUR_CMP}" "${TMP_DIR}/${YOUR_UNCMP}" 1>/dev/null 2>&1

  # Accuracy Test: `cmp`'s return code indicates if the uncompressed file is identical to the original
  if ! cmp -s "${input_file}" "${TMP_DIR}/${YOUR_UNCMP}"; then
    echo -e "[${TXT_RED}INACCURATE${TXT_RESET}]"
    echo -e "${TXT_RED}Note: Did not finish all tests. ${TXT_RESET}"
    exit 1 # unsuccessful
  else
    # Compression Ratio Test
    if [[ "$ENABLE_RATIO_TEST" = true ]]; then
      # generate `refcompress` compressed version of input_file for compression ratio test
      ./refcompress "${input_file}" "${TMP_DIR}/${REF_CMP}" 1>/dev/null 2>&1
      compression_ratio_test
    else
      echo -e "[${TXT_YELLOW}ACCURATE${TXT_RESET}]"
    fi
  fi
done

echo "All tests finished. "
exit 0 # successful
