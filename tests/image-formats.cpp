#include <QCoreApplication>
#include <QImageReader>
#include <iostream>

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    for (int i = 1; i < argc; ++i) {
        QImageReader reader(QString::fromLocal8Bit(argv[i]));
        const auto image = reader.read();
        if (image.isNull() || image.width() != 17 || image.height() != 13) {
            std::cerr << argv[i] << ": " << reader.errorString().toStdString() << '\n';
            return 1;
        }
    }
}
