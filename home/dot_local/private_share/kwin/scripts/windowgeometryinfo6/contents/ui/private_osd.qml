/*
    KWin - the KDE window manager
    This file is part of the KDE project.

    SPDX-FileCopyrightText: 2022 Richard Qian <richWiki101@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick;
import QtQuick.Controls;
import QtQuick.Window;
import org.kde.plasma.components as PlasmaComponents;
import org.kde.plasma.core as PlasmaCore;
import org.kde.kwin;

PlasmaCore.Dialog {
    id: dialog

    required property QtObject window

    x: window.x + (window.width - width) / 2
    y: window.y + (window.height - height) / 2

    location: PlasmaCore.Types.Floating
    visible: true
    flags: Qt.X11BypassWindowManagerHint | Qt.FramelessWindowHint
    outputOnly: true

    mainItem: Item {
        id: dialogItem
        width: infoElement.width
        height: infoElement.height

        PlasmaComponents.Label {
            id: infoElement
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: `(${window.x}, ${window.y})<br>` +
                `<b>${window.width}</b> × <b>${window.height}</b>`
        }
    }
}
