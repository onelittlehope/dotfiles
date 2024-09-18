/*
    KWin - the KDE window manager
    This file is part of the KDE project.

    SPDX-FileCopyrightText: 2022 Richard Qian <richWiki101@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick;
import org.kde.kwin;

Item {
    id: root

    Loader {
        id: mainItemLoader
    }

    function handleWindow(window) {
        window.interactiveMoveResizeStarted.connect(() => {
            if (!mainItemLoader.item) {
                mainItemLoader.setSource("osd.qml", { "window": window });
            }
        });
        window.interactiveMoveResizeFinished.connect(() => {
            mainItemLoader.source = "";
        });
    }

    Connections {
        target: Workspace
        function onWindowAdded(window) {
            root.handleWindow(window);
        }
    }

    Component.onCompleted: {
        for (const window of Workspace.windows) {
            root.handleWindow(window);
        }
    }
}
