#include <QCoreApplication>
#include <QDir>
#include <QJsonArray>
#include <QJsonObject>
#include <QPluginLoader>
#include <QRawFont>
#include <QTimer>
#include <cstdio>
#include <cstdlib>

static void fail(const QString &message) {
    std::fprintf(stderr, "%s\n", qPrintable(message));
    std::exit(1);
}

// Run inside the installed UI so we check its embedded fonts and plugin paths.
static void checkUiResources() {
    QTimer::singleShot(0, [] {
        for (int fill : {0, 1}) {
            const auto path = QString(":/Qcm/Material/assets/MaterialSymbolsRounded.wght_400.opsz_24.fill_%1.woff2")
                                  .arg(fill);
            const QRawFont font(path, 24);
            if (!font.isValid() || !font.supportsCharacter(0xe5d2) || !font.supportsCharacter(0xe1bc))
                fail("Missing Material menu/wallpaper glyphs in " + path);
        }

        bool decorationFound = false;
        for (const auto &path : QCoreApplication::libraryPaths()) {
            const QDir directory(path + "/wayland-decoration-client");
            for (const auto &file : directory.entryList({"*.so"}, QDir::Files)) {
                QPluginLoader plugin(directory.filePath(file));
                if (!plugin.metaData().value("MetaData").toObject().value("Keys").toArray().contains("adwaita"))
                    continue;
                if (!plugin.load())
                    fail("Cannot load Adwaita decoration: " + plugin.errorString());
                decorationFound = true;
            }
        }
        if (!decorationFound)
            fail("UI plugin paths do not contain the Adwaita Wayland decoration");

        std::fputs("UI fonts and Adwaita decoration: OK\n", stderr);
        QCoreApplication::exit(0);
    });
}

Q_COREAPP_STARTUP_FUNCTION(checkUiResources)
