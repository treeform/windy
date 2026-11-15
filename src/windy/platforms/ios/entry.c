extern void NimMain(void);
extern int windyIosMain(int argc, char **argv);

int main(int argc, char **argv) {
    NimMain();
    return windyIosMain(argc, argv);
}
