source common.sh

cd $TEST_ROOT

echo example > example.txt
mkdir -p ./x

NIX_STORE_DIR=$TEST_ROOT/x

CORRECT_PATH=$(nix-store --store ./x --add example.txt)

PATH1=$(nix path-info --store ./x $CORRECT_PATH)
[ $CORRECT_PATH == $PATH1 ]

PATH2=$(nix path-info --store "$PWD/x" $CORRECT_PATH)
[ $CORRECT_PATH == $PATH2 ]

PATH3=$(nix path-info --store "local?root=$PWD/x" $CORRECT_PATH)
[ $CORRECT_PATH == $PATH3 ]

# Ensure store ping trusted works with local store
nix --store ./x store ping --json | jq -e '.trusted'

# Suppress grumpiness about multiple nixes on PATH
(nix --store ./x doctor || true) 2>&1 | grep 'You are trusted by'
