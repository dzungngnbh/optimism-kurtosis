.PHONY: install clean

install:
	sudo kurtosis run --enclave rollup . --args-file network_params.yaml	

clean:
	sudo kurtosis clean -a