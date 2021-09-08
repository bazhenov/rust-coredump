.PHONY = clean core-dump.zst

COREDUMP_LOCATION:=/var/lib/systemd/coredump

PRODUCTION_EXECUTABLE:=target/release/examples/core-dump-stripped
DEBUG_EXECUTABLE:=target/release/examples/core-dump

$(DEBUG_EXECUTABLE): examples/core-dump.rs Cargo.toml
	cargo build --release --example=core-dump

$(PRODUCTION_EXECUTABLE): $(DEBUG_EXECUTABLE)
	strip $< -o $@

core-dump.zst: $(PRODUCTION_EXECUTABLE)
	@echo Running $(PRODUCTION_EXECUTABLE)
	$(eval PID=$(shell echo $$$$; exec $<))
	@echo Crashed PID $(PID)
	@ln -sf `ls -t $(COREDUMP_LOCATION)/*$(PID)*.zst | head -1` $@

core-dump: core-dump.zst
	@unzstd -f $<

clean:
	rm -f core-dump core-dump.zst $(PRODUCTION_EXECUTABLE)

gdb: $(DEBUG_EXECUTABLE) core-dump
	rust-gdb -q $?