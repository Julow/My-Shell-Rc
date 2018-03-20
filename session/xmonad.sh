# Xmonad

if ! which xmonad >/dev/null; then
	exit 100
fi

XMONAD_DIR="$HOME/.xmonad"
XMONAD_CONF="$XMONAD_DIR/xmonad.hs"

cp "$SESSION_DIR/xmonad.hs" "$XMONAD_CONF"