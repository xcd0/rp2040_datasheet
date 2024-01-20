export PATH := $(PATH):$(HOME)/.cargo/bin;

all:
	make chown
	make clean
	make build

clean:
	rm -rf book
	mdbook clean

build:
	mdbook build

chown:
	sudo chown y-hayasaki:y-hayasaki -R .

win:
	# msysなどsudoがない環境
	make clean
	make build

install:
	# toc
	#cargo install mdbook-pagetoc mdbook-theme mdbook-mermaid
	make install-cargo-binstall
	make install-mdbook
	make install-mdbook-mermaid
	make install-mdbook-pagetoc
	make install-mdbook-theme

serve:
	sudo bash /share/docs/serve.sh

push:
	./push.sh

install-cargo-binstall:
	if !(type cargo-binstall >/dev/null 2>&1); then curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash; else echo -n "cargo-binstall is "; which cargo-binstall; fi
install-mdbook:
	cargo binstall -y mdbook
install-mdbook-mermaid:
	cargo binstall -y mdbook-mermaid
install-mdbook-pagetoc:
	cargo binstall -y mdbook-pagetoc
install-mdbook-theme:
	cargo binstall -y mdbook-theme
mermaid-install:
	mdbook-mermaid install
