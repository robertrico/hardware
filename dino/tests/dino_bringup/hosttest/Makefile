# Host-side unit tests — system compiler, no AVR headers.
test: test_shell
	./test_shell
test_shell: test_shell.c ../src/shell_parse.c
	cc -std=c99 -Wall -Werror -DHOST_TEST -o $@ $^
clean:
	rm -f test_shell
.PHONY: test clean
