#ifndef SHELL_H
#define SHELL_H

typedef enum { CMD_LIST, CMD_RUN_ALL, CMD_RUN_MODULE, CMD_RUN_ONE,
               CMD_PINS, CMD_SELFTEST_MOD, CMD_IDLE, CMD_HELP,
               CMD_BAD } cmd_kind_t;
typedef struct { cmd_kind_t kind; char module[24]; char test[24]; } cmd_t;

cmd_t shell_parse(const char *line);
void selftest_module(const char *module);   /* mod_selftest.c */
void shell_execute(const cmd_t *c);

#endif
