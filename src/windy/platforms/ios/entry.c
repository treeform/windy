extern void NimMain(void);
extern int windyIosMain(int argc, char **argv);

int cmdCount;
char **cmdLine;

int main(int argc, char **argv) {
    cmdCount = argc;
    cmdLine = argv;
    NimMain();
    return windyIosMain(argc, argv);
}
