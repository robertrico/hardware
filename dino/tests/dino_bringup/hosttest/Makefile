# Host-side unit tests — system compiler, no AVR headers.
test: test_shell test_crc16 test_cw_expect test_mdr_expect test_reg_expect test_mar_expect test_mem_expect test_alu_expect
	./test_shell
	./test_crc16
	./test_cw_expect
	./test_mdr_expect
	./test_reg_expect
	./test_mar_expect
	./test_mem_expect
	./test_alu_expect
test_shell: test_shell.c ../src/shell_parse.c
	cc -std=c99 -Wall -Werror -DHOST_TEST -o $@ $^
test_crc16: test_crc16.c ../src/crc16.c ../src/microcode_expect.h
	cc -std=c99 -Wall -Werror -DHOST_TEST -o $@ test_crc16.c ../src/crc16.c
test_cw_expect: test_cw_expect.c ../src/cw_expect.h
	cc -std=c99 -Wall -Werror -DHOST_TEST -o $@ test_cw_expect.c
test_mdr_expect: test_mdr_expect.c ../src/mdr_expect.h
	cc -std=c99 -Wall -Werror -DHOST_TEST -o $@ test_mdr_expect.c
test_reg_expect: test_reg_expect.c ../src/reg_expect.h
	cc -std=c99 -Wall -Werror -DHOST_TEST -o $@ test_reg_expect.c
test_mar_expect: test_mar_expect.c ../src/mar_expect.h
	cc -std=c99 -Wall -Werror -DHOST_TEST -o $@ test_mar_expect.c
test_mem_expect: test_mem_expect.c ../src/mem_expect.h
	cc -std=c99 -Wall -Werror -DHOST_TEST -o $@ test_mem_expect.c
test_alu_expect: test_alu_expect.c ../src/alu_expect.h
	cc -std=c99 -Wall -Werror -DHOST_TEST -o $@ test_alu_expect.c
clean:
	rm -f test_shell test_crc16 test_cw_expect test_mdr_expect test_reg_expect test_mar_expect test_mem_expect test_alu_expect
.PHONY: test clean
