import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.battery

Item {
    id: root
    implicitWidth: 204; implicitHeight: 50
    width: 204; height: 50

    property Item liveBgItem: null
    property var notificationModel: null
    property bool notificationsShown: false
    property bool flashlightActive: false

    signal toggleNotificationsRequested()
    signal openNotificationsRequested()
    signal closeNotificationsRequested()
    signal setFlashlightRequested(bool enabled)

    property bool flashlightExpanded: false
    property real flashlightExpandT: 0.0
    property real cornerArcPopT: 0.0

    SequentialAnimation {
        id: cornerArcOpenAnim
        PauseAnimation { duration: 95 }
        NumberAnimation { target: root; property: "cornerArcPopT"; to: 1.0; duration: 390; easing.type: Easing.OutBack; easing.overshoot: 1.48 }
    }
    NumberAnimation {
        id: cornerArcCloseAnim
        target: root; property: "cornerArcPopT"; to: 0.0; duration: 245; easing.type: Easing.InCubic
    }
    property real flashlightTargetLevel: 0.78
    property real flashlightVisualLevel: 0.78
    property real flashlightTargetSpread: 0.0
    property real flashlightBeamSpread: 0.0
    property real lastNonZeroLevel: 0.78
    property bool flashlightCardPresent: false
    property bool flashlightTucked: false

    Behavior on flashlightVisualLevel { SpringAnimation { spring: 5.6; damping: 0.56; epsilon: 0.001 } }
    Behavior on flashlightBeamSpread { SpringAnimation { spring: 4.8; damping: 0.42; epsilon: 0.001 } }

    NumberAnimation {
        id: flashMorphOpenAnim; target: root; property: "flashlightExpandT"
        to: 1.0; duration: 410; easing.type: Easing.OutBack; easing.overshoot: 0.85
    }
    NumberAnimation {
        id: flashMorphCloseAnim; target: root; property: "flashlightExpandT"
        to: 0.0; duration: 415; easing.type: Easing.OutBack; easing.overshoot: 0.62
    }

    onFlashlightExpandedChanged: {
        flashMorphOpenAnim.stop(); flashMorphCloseAnim.stop(); cornerArcOpenAnim.stop(); cornerArcCloseAnim.stop();
        if (flashlightExpanded) {
            briefExpanded = false; flashlightTucked = false;
            flashMorphOpenAnim.start(); cornerArcOpenAnim.start();
            if (!flashlightActive && flashlightTargetLevel <= 0.06) flashOffInactivityTimer.restart();
        } else {
            flashOffInactivityTimer.stop(); flashMorphCloseAnim.start(); cornerArcCloseAnim.start();
            if (!flashlightActive) postCollapseTuckTimer.restart();
        }
    }

    function cloneCard(c, overrides) {
        if (!c) return null;
        var o = {
            type: c.type, label: c.label, svg: c.svg || "", fallbackIcon: c.fallbackIcon || "",
            bgC1: c.bgC1, bgC2: c.bgC2, c1: c.c1, c2: c.c2,
            bgGradOpacity: c.bgGradOpacity, lumOpacity: c.lumOpacity,
            innerShadowAlpha: c.innerShadowAlpha, hasAccentGlow: c.hasAccentGlow
        };
        if (overrides) {
            for (var k in overrides) o[k] = overrides[k];
        }
        return o;
    }

    property var restingCardSnapshot: null

    onFlashlightActiveChanged: {
        postCollapseTuckTimer.stop(); tuckFinishTimer.stop();
        if (flashlightActive) {
            flashOffInactivityTimer.stop();
            var oldSnap = root.restingCardSnapshot ? root.cloneCard(root.restingCardSnapshot, null) : root.cloneCard(root.briefCardObj, null);
            var wasFlash = root.flashlightCardPresent && !root.flashlightTucked && root.currentIndex === 0;
            root.suppressNextActiveBounce = true;
            flashlightCardPresent = true; flashlightTucked = false;
            if (flashlightTargetLevel <= 0.06) flashlightTargetLevel = Math.max(0.25, lastNonZeroLevel);
            flashlightVisualLevel = flashlightTargetLevel;
            currentIndex = 0;
            var onSnap = root.cloneCard(root.flashlightCardObj, { label: "Flashlight on", svg: "flashlight-activated.svg" });
            root.restingCardSnapshot = onSnap;
            root.suppressNextActiveBounce = false;
            if (!wasFlash && !flashlightExpanded && oldSnap && oldSnap.type !== "flashlight") {
                root.startDeckTransition(oldSnap, onSnap, true);
            }
        } else if (flashlightExpanded) {
            flashlightTargetLevel = 0.0; flashlightVisualLevel = 0.0;
            flashOffInactivityTimer.restart();
        } else {
            var wasShowingFlash = (root.restingCardSnapshot && root.restingCardSnapshot.type === "flashlight") || (root.activeCard && root.activeCard.type === "flashlight");
            var outFlashSnap = root.cloneCard(root.flashlightCardObj, { label: "Flashlight on", svg: "flashlight-activated.svg" });
            root.suppressNextActiveBounce = true;
            flashlightCardPresent = false; flashlightTucked = false;
            currentIndex = 0;
            var nextSnap = root.cloneCard(root.activeCard, null);
            root.restingCardSnapshot = nextSnap;
            root.suppressNextActiveBounce = false;
            if (wasShowingFlash && nextSnap) {
                root.startDeckTransition(outFlashSnap, nextSnap, false);
            }
        }
    }

    Timer { id: flashOffInactivityTimer; interval: 4000; onTriggered: if (!root.flashlightActive) root.flashlightExpanded = false }
    Timer {
        id: postCollapseTuckTimer; interval: 595
        onTriggered: {
            if (!root.flashlightActive && !root.flashlightExpanded) {
                var outCard = root.cloneCard(root.flashlightCardObj, { label: "Flashlight off", svg: "flashlight-unactivated.svg" });
                root.suppressNextActiveBounce = true;
                root.flashlightCardPresent = false; root.flashlightTucked = false; root.currentIndex = 0;
                var inCard = root.cloneCard(root.activeCard, null);
                root.restingCardSnapshot = inCard;
                root.suppressNextActiveBounce = false;
                if (inCard) root.startDeckTransition(outCard, inCard, false);
            }
        }
    }
    Timer { id: tuckFinishTimer; interval: 260 }

    Loader { id: wpPathLoader; source: "file:///home/jayjayc/.config/argon-wallpapers.qml" }
    Item {
        id: internalBlurredBg
        x: {
            var _dep = root.x + (root.parent ? root.parent.x : 0) + (root.Window.width || 0);
            return -root.mapToItem(null, 0, 0).x + _dep * 0.0;
        }
        y: {
            var _dep = root.y + (root.parent ? root.parent.y : 0) + (root.Window.height || 0);
            return -root.mapToItem(null, 0, 0).y + _dep * 0.0;
        }
        width: root.Window.width > 0 ? root.Window.width : 393
        height: root.Window.height > 0 ? root.Window.height : 852
        visible: false
        layer.enabled: true
        layer.smooth: true
        layer.textureMirroring: ShaderEffectSource.NoMirroring

        Image {
            id: fallbackWpImg
            anchors.fill: parent
            visible: root.liveBgItem === null
            fillMode: Image.PreserveAspectCrop
            smooth: true
            source: (wpPathLoader.item && wpPathLoader.item.lockUrl && wpPathLoader.item.lockUrl.length > 0) ? wpPathLoader.item.lockUrl : "file:///home/jayjayc/custom-wallpaper.png"
        }

        MultiEffect {
            anchors.fill: parent
            source: root.liveBgItem ? root.liveBgItem : fallbackWpImg
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 30
            blur: 1.0
        }
    }
    property var sharedBlurredBg: internalBlurredBg

    property bool briefExpanded: false
    property real briefExpandT: 0.0
    property real briefPillOpacity: (briefExpanded || briefExpandT > 0.004 || briefExpandT < -0.002) ? 0.0 : 1.0

    NumberAnimation { id: briefOpenAnim; target: root; property: "briefExpandT"; to: 1.0; duration: 860; easing.type: Easing.OutBack; easing.overshoot: 0.62 }
    NumberAnimation { id: briefCloseAnim; target: root; property: "briefExpandT"; to: 0.0; duration: 800; easing.type: Easing.OutBack; easing.overshoot: 0.50 }
    onBriefExpandedChanged: {
        briefOpenAnim.stop(); briefCloseAnim.stop();
        if (briefExpanded) briefOpenAnim.start();
        else briefCloseAnim.start();
    }
    property string weatherTemp: "26°"
    property string weatherCond: "Clear"
    property string customBriefTitle: ""
    property string customBriefSummary: ""
    property bool drivingModeActive: false
    property string mediaTitle: ""
    property int sysBatteryPercent: -1
    property bool sysBatteryCharging: false

    readonly property int hourOfDay: (new Date()).getHours()
    readonly property string briefPeriod: hourOfDay >= 5 && hourOfDay < 11 ? "morning" : (hourOfDay >= 11 && hourOfDay < 15 ? "midday" : (hourOfDay >= 15 && hourOfDay < 20 ? "afternoon" : "night"))
    readonly property string briefTitleText: customBriefTitle.length > 0 ? customBriefTitle : (briefPeriod === "morning" ? "Morning brief" : (briefPeriod === "midday" ? "Mid-day brief" : (briefPeriod === "afternoon" ? "Afternoon brief" : "Night brief")))
    readonly property string briefSvgIcon: briefPeriod + "-icon.svg"

    BatteryControlModel { id: batteryControl }
    readonly property int effectiveBatPercent: sysBatteryPercent >= 0 ? sysBatteryPercent : (batteryControl.hasInternalBatteries ? batteryControl.percent : 84)
    onEffectivePluggedChanged: {
        if (effectivePlugged && !flashlightExpanded && flashlightExpandT < 0.02) {
            var prev = root.activeCard;
            root.suppressNextActiveBounce = true;
            for (var i = 0; i < cards.length; ++i) { if (cards[i].type === 'battery') { currentIndex = i; break; } }
            root.suppressNextActiveBounce = false;
            if (prev && prev.type !== 'battery') root.startDeckTransition(prev, root.chargingCardObj, true);
        }
    }
    readonly property bool effectivePlugged: sysBatteryCharging || (batteryControl.hasInternalBatteries && batteryControl.pluggedIn)
    readonly property string briefSummaryText: customBriefSummary.length > 0 ? customBriefSummary : (weatherTemp + " " + weatherCond + "  •  " + effectiveBatPercent + "% battery")

    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var xhr = new XMLHttpRequest();
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE && (xhr.status === 200 || xhr.status === 0) && xhr.responseText.length > 2) {
                    try {
                        var d = JSON.parse(xhr.responseText);
                        if (d.title !== undefined) root.customBriefTitle = String(d.title);
                        if (d.summary !== undefined) root.customBriefSummary = String(d.summary);
                        if (d.temp !== undefined) root.weatherTemp = String(d.temp);
                        if (d.condition !== undefined) root.weatherCond = String(d.condition);
                        if (d.driving !== undefined) root.drivingModeActive = Boolean(d.driving);
                        if (d.mediaTitle !== undefined) root.mediaTitle = String(d.mediaTitle);
                        if (d.batteryPercent !== undefined) root.sysBatteryPercent = Number(d.batteryPercent);
                        if (d.charging !== undefined) root.sysBatteryCharging = Boolean(d.charging);
                    } catch (e) {}
                }
            };
            xhr.open("GET", "file:///tmp/now_brief.json"); xhr.send();
        }
    }

    Timer {
        interval: 600000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var w = new XMLHttpRequest();
            w.onreadystatechange = function() {
                if (w.readyState === XMLHttpRequest.DONE && w.status === 200) {
                    try {
                        var r = JSON.parse(w.responseText);
                        if (r.current_weather) {
                            root.weatherTemp = Math.round(r.current_weather.temperature) + "°";
                            var c = r.current_weather.weathercode;
                            root.weatherCond = c === 0 ? "Clear" : (c <= 3 ? "Partly Cloudy" : (c <= 67 ? "Rain" : "Storm"));
                        }
                    } catch (e) {}
                }
            };
            w.open("GET", "https://open-meteo.com"); w.send();
        }
    }

    readonly property var flashlightCardObj: ({
        type: "flashlight", label: root.flashlightActive ? "Flashlight on" : "Flashlight off",
        svg: root.flashlightActive ? "flashlight-activated.svg" : "flashlight-unactivated.svg",
        bgC1: "#264EC9", bgC2: "#1D3896", c1: "#5868FF", c2: "#3B1EFF", bgGradOpacity: 0.13, lumOpacity: 0.15, innerShadowAlpha: 0.15, hasAccentGlow: true
    })
    readonly property var briefCardObj: ({
        type: "brief", label: root.briefTitleText, svg: root.briefSvgIcon,
        bgC1: root.briefPeriod === "morning" ? "#5C3B14" : (root.briefPeriod === "afternoon" ? "#5E2750" : "#1E3A8A"),
        bgC2: root.briefPeriod === "morning" ? "#3B230A" : (root.briefPeriod === "afternoon" ? "#381534" : "#15255E"),
        c1: root.briefPeriod === "morning" ? "#FFB82E" : (root.briefPeriod === "afternoon" ? "#FF8A3D" : "#6366F1"),
        c2: root.briefPeriod === "morning" ? "#FF7700" : (root.briefPeriod === "afternoon" ? "#E03E73" : "#3B82F6"),
        bgGradOpacity: 0.14, lumOpacity: 0.15, innerShadowAlpha: 0.16, hasAccentGlow: true
    })
    readonly property var chargingCardObj: ({
        type: "battery", label: root.effectiveBatPercent + "% Charged", svg: "", fallbackIcon: "battery-charging",
        bgC1: "#0F766E", bgC2: "#064E3B", c1: "#34D399", c2: "#10B981", bgGradOpacity: 0.15, lumOpacity: 0.15, innerShadowAlpha: 0.16, hasAccentGlow: true
    })
    readonly property var extraCardObj: ({
        type: root.drivingModeActive ? "driving" : "media", label: root.drivingModeActive ? "Driving mode" : root.mediaTitle,
        svg: "", fallbackIcon: root.drivingModeActive ? "car" : "media-playback-start",
        bgC1: "#1E293B", bgC2: "#0F172A", c1: "#60A5FA", c2: "#3B82F6", bgGradOpacity: 0.13, lumOpacity: 0.15, innerShadowAlpha: 0.15, hasAccentGlow: false
    })

    readonly property var cards: {
        var arr = [];
        if (root.flashlightCardPresent && !root.flashlightTucked) arr.push(root.flashlightCardObj);
        arr.push(root.briefCardObj);
        if (root.effectivePlugged) arr.push(root.chargingCardObj);
        arr.push({ type: "driving", label: root.mediaTitle.length > 0 ? root.mediaTitle : "Driving mode", svg: "", fallbackIcon: root.mediaTitle.length > 0 ? "media-playback-start" : "car", bgC1: "#1B3278", bgC2: "#122254", c1: "#3D7BFF", c2: "#2452E6", bgGradOpacity: 0.13, lumOpacity: 0.15, innerShadowAlpha: 0.15, hasAccentGlow: true });
        return arr;
    }
    property int currentIndex: 0
    onCardsChanged: if (currentIndex >= cards.length) currentIndex = Math.max(0, cards.length - 1)
    readonly property var activeCard: cards.length > 0 ? cards[Math.min(currentIndex, cards.length - 1)] : null

    component PillCard : Item {
        id: cardRoot
        property var card: null
        property bool contentOnly: false
        property bool interactiveCard: false
        property real extraContentBlur: 0.0

        readonly property bool isFlashCard: card !== null && card.type === "flashlight"
        readonly property real expT: (isFlashCard && interactiveCard) ? Math.max(-0.06, Math.min(1.2, root.flashlightExpandT)) : 0.0
        readonly property real clampedT: Math.max(0.0, Math.min(1.0, expT))

        width: 170 + (166 - 170) * Math.max(0.0, expT) - Math.min(0.0, expT) * 58.0
        height: Math.max(46.5, 50 + (246 - 50) * expT)
        property real radius: 25 + (30 - 25) * clampedT

        Canvas {
            visible: !cardRoot.contentOnly && cardRoot.interactiveCard && root.cards.length > 1 && cardRoot.clampedT < 0.26 && !colorOsSwipeStage.active && root.briefPillOpacity > 0.5
            opacity: Math.max(0.0, 1.0 - cardRoot.clampedT / 0.26) * 0.44 * root.briefPillOpacity
            x: -20; y: 0; width: cardRoot.width + 40; height: cardRoot.height
            z: -1
            onVisibleChanged: if (visible) requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                var ctx = getContext("2d"); ctx.reset();
                ctx.strokeStyle = "rgb(160, 175, 205)"; ctx.lineWidth = 3.2; ctx.lineCap = "round";
                var cxMid = width * 0.5; var cy = height * 0.5;
                ctx.beginPath(); ctx.arc(cxMid - 90.25 + 32.0, cy, 32.0, Math.PI - 0.56, Math.PI + 0.56, false); ctx.stroke();
                ctx.beginPath(); ctx.arc(cxMid + 90.25 - 32.0, cy, 32.0, -0.56, 0.56, false); ctx.stroke();
            }
        }

        Item {
            id: pillBodyBox
            anchors.fill: parent

            Rectangle { id: cMask; anchors.fill: parent; radius: cardRoot.radius; color: "#FFFFFF"; visible: false; layer.enabled: true; layer.smooth: true }

            Item {
                anchors.fill: parent
                visible: !cardRoot.contentOnly

                function uBg1(c) { var col = Qt.color((c && c.bgC1) ? c.bgC1 : "#264EC9"); return Qt.vector4d(col.r, col.g, col.b, (c && c.bgGradOpacity !== undefined) ? c.bgGradOpacity : 0.22); }
                function uBg2(c) { var col = Qt.color((c && c.bgC2) ? c.bgC2 : "#1D3896"); return Qt.vector4d(col.r, col.g, col.b, (c && c.type === "flashlight") ? 2.0 : ((c && c.hasAccentGlow) ? 1.0 : 0.0)); }
                function uC1(c) { var col = Qt.color((c && c.c1) ? c.c1 : "#367DFF"); return Qt.vector4d(col.r, col.g, col.b, (c && c.lumOpacity !== undefined) ? c.lumOpacity : 0.22); }
                function uC2(c) { var col = Qt.color((c && c.c2) ? c.c2 : "#4000FF"); return Qt.vector4d(col.r, col.g, col.b, (c && c.innerShadowAlpha !== undefined) ? c.innerShadowAlpha : 0.15); }

                ShaderEffect {
                    id: unifiedCardGlassShader
                    readonly property real outerPad: (cardRoot.isFlashCard && cardRoot.interactiveCard) ? 14.0 : 0.0
                    anchors.fill: parent
                    anchors.margins: -outerPad
                    opacity: 1.0
                    visible: true
                    property real progress: cardRoot.radius
                    property real dir: cardRoot.clampedT
                    property real passMode: 4.0
                    property vector2d itemSize: Qt.vector2d(cardRoot.width, cardRoot.height)
                    property vector2d screenSize: root.sharedBlurredBg ? Qt.vector2d(root.sharedBlurredBg.width, root.sharedBlurredBg.height) : Qt.vector2d(393, 852)
                    property vector4d bgRect: {
                        var _dep = (cardRoot.visible ? 1 : 0) + root.x + root.y + cardRoot.x + cardRoot.y + cardRoot.width + cardRoot.height + root.flashlightExpandT;
                        if (!root.sharedBlurredBg) return Qt.vector4d((393 - width) * 0.5, 750, width, height);
                        var pt = unifiedCardGlassShader.mapToItem(root.sharedBlurredBg, 0, 0);
                        return Qt.vector4d(pt.x + _dep * 0.0, pt.y, width, height);
                    }
                    property vector4d colA_bg1: parent.uBg1(cardRoot.card)
                    property vector4d colA_bg2: parent.uBg2(cardRoot.card)
                    property vector4d colA_c1: parent.uC1(cardRoot.card)
                    property vector4d colA_c2: parent.uC2(cardRoot.card)
                    property vector4d colB_bg1: Qt.vector4d(0, 0, 0, outerPad > 0.0 ? root.cornerArcPopT : 0.0)
                    property vector4d colB_bg2: Qt.vector4d(0, 0, 0, outerPad)
                    property vector4d colB_c1: colA_c1; property vector4d colB_c2: colA_c2
                    property var bgSource: root.sharedBlurredBg
                    fragmentShader: Qt.resolvedUrl("coloros_metaball.frag.qsb")
                }

                
            }

            Item {
                id: innerClipItem
                anchors.fill: parent
                layer.enabled: cardRoot.contentOnly ? false : (cardRoot.clampedT > 0.005 && cardRoot.clampedT < 0.995)
                layer.effect: OpacityMask { maskSource: cMask }

                Item {
                    id: fixedBlurCanvas
                    width: 184; height: 246
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    readonly property real morphBlurRadius: Math.pow(Math.sin(cardRoot.clampedT * Math.PI), 0.78) * 28.0
                    layer.enabled: morphBlurRadius > 0.35
                    layer.effect: FastBlur { radius: fixedBlurCanvas.morphBlurRadius; transparentBorder: true }

                    Item {
                        id: collapsedContentWrap
                        width: cardRoot.width; height: 50
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        scale: 0.92 + 0.08 * (1.0 - cardRoot.clampedT)
                        opacity: Math.max(0.0, 1.0 - cardRoot.clampedT * 1.85)
                        visible: opacity > 0.01
                        readonly property real focusBlur: cardRoot.extraContentBlur + (cardRoot.interactiveCard ? root.innerContentBlur : 0.0)
                        layer.enabled: focusBlur > 0.25
                        layer.effect: FastBlur { radius: collapsedContentWrap.focusBlur; transparentBorder: true }

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 7; anchors.rightMargin: 14; spacing: 9
                            Rectangle {
                                id: pillIconBadge
                                Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18
                                transform: [
                                    Scale {
                                        origin.x: 18; origin.y: 18
                                        xScale: cardRoot.interactiveCard ? root.innerIconScale : 1.0
                                        yScale: cardRoot.interactiveCard ? root.innerIconScale : 1.0
                                    },
                                    Translate { x: cardRoot.interactiveCard ? root.innerIconOffsetX : 0.0 }
                                ]
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: (cardRoot.card && cardRoot.card.c1) ? cardRoot.card.c1 : "#367DFF" }
                                    GradientStop { position: 1.0; color: (cardRoot.card && cardRoot.card.c2) ? cardRoot.card.c2 : "#4000FF" }
                                }
                                Image {
                                    anchors.centerIn: parent
                                    width: (cardRoot.card && cardRoot.card.type === "flashlight") ? 10 : 20
                                    height: (cardRoot.card && cardRoot.card.type === "flashlight") ? 22 : 20
                                    fillMode: Image.PreserveAspectFit
                                    visible: cardRoot.card !== null && cardRoot.card.svg !== ""
                                    source: (cardRoot.card && cardRoot.card.svg !== "") ? Qt.resolvedUrl(cardRoot.card.svg) : ""
                                    sourceSize: Qt.size(44, 44); smooth: true
                                }
                                Kirigami.Icon {
                                    anchors.centerIn: parent; width: 20; height: 20
                                    visible: cardRoot.card !== null && cardRoot.card.svg === ""
                                    source: (cardRoot.card && cardRoot.card.fallbackIcon) ? cardRoot.card.fallbackIcon : "notifications"
                                    color: "#FFFFFF"
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: cardRoot.card ? cardRoot.card.label : ""
                                color: "#FFFFFF"; font.family: "Google Sans Flex"; font.pixelSize: 15; font.weight: Font.Medium
                                elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                                transform: [
                                    Scale {
                                        origin.x: 0; origin.y: 10
                                        xScale: cardRoot.interactiveCard ? root.innerTextScale : 1.0
                                        yScale: cardRoot.interactiveCard ? root.innerTextScale : 1.0
                                    },
                                    Translate { x: cardRoot.interactiveCard ? root.innerTextOffsetX : 0.0 }
                                ]
                            }
                        }
                    }

                    Item {
                        id: expandedFlashWrap
                        width: 166; height: 246
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        transform: Scale {
                            origin.x: 83; origin.y: 221
                            xScale: 0.92 + 0.08 * cardRoot.clampedT
                            yScale: 0.32 + 0.68 * cardRoot.clampedT
                        }
                        opacity: cardRoot.isFlashCard ? Math.max(0.0, Math.min(1.0, (cardRoot.clampedT - 0.05) / 0.68)) : 0.0
                        visible: opacity > 0.01

                        ShaderEffect {
                            id: flashBeamShader
                            anchors.fill: parent; blending: true
                            property real level: root.flashlightVisualLevel
                            property real aspect: width / Math.max(1.0, height)
                            property real tilt: cardRoot.clampedT
                            property real spread: root.flashlightBeamSpread
                            fragmentShader: Qt.resolvedUrl("flashbeam.frag.qsb")
                        }

                        

                        Item {
                            id: bottomTorchIconWrap
                            width: 48; height: 52
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 192
                            readonly property real activeGlowT: Math.max(0.0, Math.min(1.0, root.flashlightVisualLevel * 1.35))

                            Image {
                                id: rawTorchSvg
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 5
                                width: 16; height: 36
                                fillMode: Image.PreserveAspectFit
                                source: Qt.resolvedUrl("flashlight-activated.svg")
                                sourceSize: Qt.size(48, 108)
                                visible: false
                                smooth: true
                            }

                            ColorOverlay {
                                anchors.fill: rawTorchSvg
                                source: rawTorchSvg
                                color: "#FFFFFF"
                                opacity: 0.42 + 0.58 * bottomTorchIconWrap.activeGlowT
                                layer.enabled: bottomTorchIconWrap.activeGlowT > 0.02
                                layer.effect: DropShadow {
                                    transparentBorder: true
                                    horizontalOffset: 0; verticalOffset: 0
                                    radius: 8; samples: 17
                                    color: Qt.rgba(0.72, 0.86, 1.0, 0.52 * bottomTorchIconWrap.activeGlowT)
                                }
                            }
                        }
                    }
                }
            }

            

            MouseArea {
                id: flash2DSliderArea
                z: 14; anchors.fill: parent
                enabled: cardRoot.interactiveCard && cardRoot.isFlashCard && root.flashlightExpanded && cardRoot.clampedT > 0.65
                visible: enabled
                property real startX: 0; property real startY: 0
                property real baseLv: 0.78; property real baseSp: 0.0
                property bool moved: false

                onPressed: (mouse) => {
                    flashOffInactivityTimer.stop(); postCollapseTuckTimer.stop();
                    startX = mouse.x; startY = mouse.y;
                    baseLv = root.flashlightActive ? root.flashlightTargetLevel : 0.0;
                    baseSp = root.flashlightTargetSpread; moved = false;
                }
                onPositionChanged: (mouse) => {
                    var dx = mouse.x - startX; var dy = mouse.y - startY;
                    if (!moved && (Math.abs(dx) > 5 || Math.abs(dy) > 5)) moved = true;
                    if (moved) {
                        var nextLv = Math.max(0.0, Math.min(1.0, baseLv - dy / 145.0));
                        var nextSp = Math.max(0.0, Math.min(1.0, baseSp + dx / 115.0));
                        root.flashlightTargetSpread = nextSp; root.flashlightBeamSpread = nextSp;
                        root.flashlightTargetLevel = nextLv; root.flashlightVisualLevel = nextLv;
                        if (nextLv <= 0.06) {
                            if (root.flashlightActive) root.setFlashlightRequested(false);
                            flashOffInactivityTimer.restart();
                        } else {
                            root.lastNonZeroLevel = nextLv;
                            if (!root.flashlightActive) root.setFlashlightRequested(true);
                            flashOffInactivityTimer.stop();
                        }
                    }
                }
                onReleased: (mouse) => {
                    if (!moved && mouse.y < 178) {
                        var tapLv = Math.max(0.12, Math.min(1.0, (178.0 - mouse.y) / 138.0));
                        var tapSp = Math.max(0.0, Math.min(1.0, Math.abs(mouse.x - width * 0.5) / 56.0));
                        root.lastNonZeroLevel = tapLv;
                        root.flashlightTargetLevel = tapLv; root.flashlightVisualLevel = tapLv;
                        root.flashlightTargetSpread = tapSp; root.flashlightBeamSpread = tapSp;
                        if (!root.flashlightActive) root.setFlashlightRequested(true);
                        flashOffInactivityTimer.stop();
                    } else if (!root.flashlightActive) {
                        flashOffInactivityTimer.restart();
                    }
                }
            }

            MouseArea {
                id: flashBottomIconToggleArea
                z: 15; width: 68; height: 62
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                enabled: cardRoot.interactiveCard && cardRoot.isFlashCard && root.flashlightExpanded && cardRoot.clampedT > 0.65
                visible: enabled
                onClicked: {
                    if (root.flashlightActive) {
                        root.lastNonZeroLevel = Math.max(0.25, root.flashlightTargetLevel);
                        root.flashlightTargetLevel = 0.0; root.flashlightVisualLevel = 0.0;
                        root.setFlashlightRequested(false);
                        flashOffInactivityTimer.restart();
                    } else {
                        flashOffInactivityTimer.stop(); postCollapseTuckTimer.stop();
                        var restore = Math.max(0.25, root.lastNonZeroLevel);
                        root.flashlightTargetLevel = restore; root.flashlightVisualLevel = restore;
                        root.setFlashlightRequested(true);
                    }
                }
            }
        }
    }

    readonly property var nextDeckCard: cards.length > 1 ? cards[(currentIndex + 1) % cards.length] : activeCard
    readonly property var prevDeckCard: cards.length > 1 ? cards[(currentIndex - 1 + cards.length) % cards.length] : activeCard
    MobileShell.HapticsEffect { id: haptics }

    Item {
        id: colorOsSwipeStage
        width: 340; height: 80; anchors.centerIn: parent; z: 12
        readonly property real overT: Math.max(0.0, t - 1.0)
        anchors.horizontalCenterOffset: swipeDir * overT * 36.0
        transform: Scale {
            origin.x: 170; origin.y: 40
            xScale: 1.0 + colorOsSwipeStage.overT * 0.42
            yScale: 1.0 + colorOsSwipeStage.overT * 0.22
        }
        property bool isDragActive: false
        property bool isSettleActive: false
        property bool isForcedMode: false
        property var forcedCardA: null
        property var forcedCardB: null
        property real t: 0.0
        property real swipeDir: 1.0
        property bool active: (isDragActive || isSettleActive) && !root.flashlightExpanded && root.flashlightExpandT < 0.01 && (isForcedMode || root.cards.length > 1)
        visible: active

        readonly property var cardA: isForcedMode ? forcedCardA : root.activeCard
        readonly property var cardB: isForcedMode ? forcedCardB : (swipeDir < 0 ? root.nextDeckCard : root.prevDeckCard)

        function sBg1(c) { var col = Qt.color((c && c.bgC1) ? c.bgC1 : "#264EC9"); return Qt.vector4d(col.r, col.g, col.b, (c && c.bgGradOpacity !== undefined) ? c.bgGradOpacity : 0.22); }
        function sBg2(c) { var col = Qt.color((c && c.bgC2) ? c.bgC2 : "#1D3896"); return Qt.vector4d(col.r, col.g, col.b, (c && c.type === "flashlight") ? 2.0 : ((c && c.hasAccentGlow) ? 1.0 : 0.0)); }
        function sC1(c) { var col = Qt.color((c && c.c1) ? c.c1 : "#367DFF"); return Qt.vector4d(col.r, col.g, col.b, (c && c.lumOpacity !== undefined) ? c.lumOpacity : 0.22); }
        function sC2(c) { var col = Qt.color((c && c.c2) ? c.c2 : "#4000FF"); return Qt.vector4d(col.r, col.g, col.b, (c && c.innerShadowAlpha !== undefined) ? c.innerShadowAlpha : 0.15); }

        NumberAnimation {
            id: swipeCommitAnim; target: colorOsSwipeStage; property: "t"; to: 1.0; duration: 375; easing.type: Easing.OutBack
            onFinished: {
                var dirSign = colorOsSwipeStage.swipeDir;
                root.suppressNextActiveBounce = true;
                if (!colorOsSwipeStage.isForcedMode && root.cards.length > 1) {
                    root.currentIndex = dirSign < 0 ? (root.currentIndex + 1) % root.cards.length : (root.currentIndex - 1 + root.cards.length) % root.cards.length;
                }
                colorOsSwipeStage.isForcedMode = false;
                colorOsSwipeStage.isSettleActive = false; colorOsSwipeStage.t = 0.0;
                root.restingCardSnapshot = root.cloneCard(root.activeCard, null);
                root.suppressNextActiveBounce = false;
            }
        }
        NumberAnimation {
            id: swipeCancelAnim; target: colorOsSwipeStage; property: "t"; to: 0.0; duration: 290; easing.type: Easing.OutBack; easing.overshoot: 0.85
            onFinished: { colorOsSwipeStage.isSettleActive = false; colorOsSwipeStage.t = 0.0; }
        }

        ShaderEffect {
            anchors.fill: parent
            property real progress: colorOsSwipeStage.t; property real dir: colorOsSwipeStage.swipeDir; property real passMode: 0.0
            property vector2d itemSize: Qt.vector2d(340, 80)
            property vector2d screenSize: Qt.vector2d(root.sharedBlurredBg.width, root.sharedBlurredBg.height)
            property vector4d bgRect: { var _dep = colorOsSwipeStage.t + root.x + root.y; var pt = colorOsSwipeStage.mapToItem(root.sharedBlurredBg, 0, 0); return Qt.vector4d(pt.x + _dep * 0.0, pt.y, 340, 80); }
            property vector4d colA_bg1: colorOsSwipeStage.sBg1(colorOsSwipeStage.cardA); property vector4d colA_bg2: colorOsSwipeStage.sBg2(colorOsSwipeStage.cardA)
            property vector4d colA_c1: colorOsSwipeStage.sC1(colorOsSwipeStage.cardA); property vector4d colA_c2: colorOsSwipeStage.sC2(colorOsSwipeStage.cardA)
            property vector4d colB_bg1: colorOsSwipeStage.sBg1(colorOsSwipeStage.cardB); property vector4d colB_bg2: colorOsSwipeStage.sBg2(colorOsSwipeStage.cardB)
            property vector4d colB_c1: colorOsSwipeStage.sC1(colorOsSwipeStage.cardB); property vector4d colB_c2: colorOsSwipeStage.sC2(colorOsSwipeStage.cardB)
            property var bgSource: root.sharedBlurredBg; fragmentShader: Qt.resolvedUrl("coloros_metaball.frag.qsb")
        }

        ShaderEffect {
            id: maskLobeA; anchors.fill: parent; visible: false; layer.enabled: true
            property real progress: colorOsSwipeStage.t; property real dir: colorOsSwipeStage.swipeDir; property real passMode: 1.0
            property vector2d itemSize: Qt.vector2d(340, 80); property vector2d screenSize: Qt.vector2d(393, 852); property vector4d bgRect: Qt.vector4d(0, 0, 340, 80)
            property vector4d colA_bg1: Qt.vector4d(0,0,0,0); property vector4d colA_bg2: Qt.vector4d(0,0,0,0); property vector4d colA_c1: Qt.vector4d(0,0,0,0); property vector4d colA_c2: Qt.vector4d(0,0,0,0)
            property vector4d colB_bg1: Qt.vector4d(0,0,0,0); property vector4d colB_bg2: Qt.vector4d(0,0,0,0); property vector4d colB_c1: Qt.vector4d(0,0,0,0); property vector4d colB_c2: Qt.vector4d(0,0,0,0)
            property var bgSource: root.sharedBlurredBg; fragmentShader: Qt.resolvedUrl("coloros_metaball.frag.qsb")
        }
        Item {
            anchors.fill: parent; layer.enabled: true; layer.effect: OpacityMask { maskSource: maskLobeA }
            PillCard { y: 15; x: (340 - 170) * 0.5 + colorOsSwipeStage.swipeDir * colorOsSwipeStage.t * 54.0; scale: 1.0 - 0.18 * Math.min(1.0, colorOsSwipeStage.t); extraContentBlur: Math.min(1.0, colorOsSwipeStage.t * 1.45) * 15.5; opacity: 1.0 - Math.min(1.0, colorOsSwipeStage.t * 1.38); card: colorOsSwipeStage.cardA; contentOnly: true }
        }

        ShaderEffect {
            id: maskLobeB; anchors.fill: parent; visible: false; layer.enabled: true
            property real progress: colorOsSwipeStage.t; property real dir: colorOsSwipeStage.swipeDir; property real passMode: 3.0
            property vector2d itemSize: Qt.vector2d(340, 80); property vector2d screenSize: Qt.vector2d(393, 852); property vector4d bgRect: Qt.vector4d(0, 0, 340, 80)
            property vector4d colA_bg1: Qt.vector4d(0,0,0,0); property vector4d colA_bg2: Qt.vector4d(0,0,0,0); property vector4d colA_c1: Qt.vector4d(0,0,0,0); property vector4d colA_c2: Qt.vector4d(0,0,0,0)
            property vector4d colB_bg1: Qt.vector4d(0,0,0,0); property vector4d colB_bg2: Qt.vector4d(0,0,0,0); property vector4d colB_c1: Qt.vector4d(0,0,0,0); property vector4d colB_c2: Qt.vector4d(0,0,0,0)
            property var bgSource: root.sharedBlurredBg; fragmentShader: Qt.resolvedUrl("coloros_metaball.frag.qsb")
        }
        Item {
            anchors.fill: parent; layer.enabled: true; layer.effect: OpacityMask { maskSource: maskLobeB }
            PillCard { y: 15; x: (340 - 170) * 0.5 - colorOsSwipeStage.swipeDir * (1.0 - colorOsSwipeStage.t) * 46.0; scale: 0.86 + 0.14 * colorOsSwipeStage.t; extraContentBlur: Math.max(0.0, 1.0 - Math.min(1.0, colorOsSwipeStage.t * 1.08)) * 16.0; opacity: Math.min(1.0, Math.max(0.0, (colorOsSwipeStage.t - 0.12) / 0.72)); card: colorOsSwipeStage.cardB; contentOnly: true }
        }

        ShaderEffect {
            anchors.fill: parent
            property real progress: colorOsSwipeStage.t; property real dir: colorOsSwipeStage.swipeDir; property real passMode: 2.0
            property vector2d itemSize: Qt.vector2d(340, 80); property vector2d screenSize: Qt.vector2d(393, 852); property vector4d bgRect: Qt.vector4d(0, 0, 340, 80)
            property vector4d colA_bg1: colorOsSwipeStage.sBg1(colorOsSwipeStage.cardA); property vector4d colA_bg2: colorOsSwipeStage.sBg2(colorOsSwipeStage.cardA)
            property vector4d colA_c1: colorOsSwipeStage.sC1(colorOsSwipeStage.cardA); property vector4d colA_c2: colorOsSwipeStage.sC2(colorOsSwipeStage.cardA)
            property vector4d colB_bg1: colorOsSwipeStage.sBg1(colorOsSwipeStage.cardB); property vector4d colB_bg2: colorOsSwipeStage.sBg2(colorOsSwipeStage.cardB)
            property vector4d colB_c1: colorOsSwipeStage.sC1(colorOsSwipeStage.cardB); property vector4d colB_c2: colorOsSwipeStage.sC2(colorOsSwipeStage.cardB)
            property var bgSource: root.sharedBlurredBg; fragmentShader: Qt.resolvedUrl("coloros_metaball.frag.qsb")
        }
    }

    // yo watch this lava lamp blob split its soul in half and reveal driving mode underneath!!
    // ayo turn into a 34x34 marble FIRST then liquid-spit the brief card out the top!!
    Item {
        id: briefLiquidStage
        width: 310; height: 240
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -15
        z: 28
        readonly property real bt: root.briefExpandT
        readonly property real cbt: Math.max(0.0, Math.min(1.0, bt))
        visible: (root.briefExpanded || bt > 0.004 || bt < -0.002) && root.flashlightExpandT < 0.01

        // Plateau at 1.0 (34x34 circle) across cbt = 0.28..0.56 while the top blob buds out / pours back in!
        readonly property real ballM: {
            if (bt < 0.0) return bt * 0.45;
            if (bt > 1.0) return -(bt - 1.0) * 0.45;
            if (cbt < 0.28) { var u = cbt / 0.28; return u * u * (3.0 - 2.0 * u); }
            if (cbt <= 0.56) return 1.0;
            var v = (1.0 - cbt) / 0.44;
            return v * v * (3.0 - 2.0 * v);
        }
        readonly property real cBall: Math.max(0.0, Math.min(1.0, ballM))
        readonly property real botW: Math.max(30.0, 170.0 + (34.0 - 170.0) * ballM)
        readonly property real botH: Math.max(30.0, 50.0 + (34.0 - 50.0) * cBall)
        readonly property real emergeT: bt <= 0.26 ? 0.0 : ((bt - 0.26) / 0.74)

        readonly property var topBriefCard: root.briefCardObj
        readonly property var underDeckCard: {
            for (var i = 0; i < root.cards.length; ++i) {
                if (root.cards[i].type !== "brief") return root.cards[i];
            }
            return root.briefCardObj;
        }

        // Side stack arcs contract into the 34x34 circle and spread back out with botW!
        Canvas {
            visible: root.cards.length > 1 && briefLiquidStage.cBall < 0.65
            opacity: Math.max(0.0, 1.0 - briefLiquidStage.cBall / 0.65) * 0.44
            width: briefLiquidStage.botW + 40; height: 50
            anchors.horizontalCenter: parent.horizontalCenter; y: 175
            onWidthChanged: if (visible) requestPaint()
            onVisibleChanged: if (visible) requestPaint()
            onPaint: {
                var ctx = getContext("2d"); ctx.reset();
                ctx.strokeStyle = "rgb(160, 175, 205)"; ctx.lineWidth = 3.2; ctx.lineCap = "round";
                var cxMid = width * 0.5; var cy = height * 0.5; var hw = briefLiquidStage.botW * 0.5;
                ctx.beginPath(); ctx.arc(cxMid - (hw + 5.25) + 32.0, cy, 32.0, Math.PI - 0.56, Math.PI + 0.56, false); ctx.stroke();
                ctx.beginPath(); ctx.arc(cxMid + (hw + 5.25) - 32.0, cy, 32.0, -0.56, 0.56, false); ctx.stroke();
            }
        }

        ShaderEffect {
            anchors.fill: parent
            property real progress: briefLiquidStage.bt
            property real dir: briefLiquidStage.ballM
            property real passMode: 5.0
            property vector2d itemSize: Qt.vector2d(310, 240)
            property vector2d screenSize: root.sharedBlurredBg ? Qt.vector2d(root.sharedBlurredBg.width, root.sharedBlurredBg.height) : Qt.vector2d(393, 852)
            property vector4d bgRect: {
                var _dep = briefLiquidStage.bt + root.x + root.y;
                if (!root.sharedBlurredBg) return Qt.vector4d((393 - 310) * 0.5, 600, 310, 240);
                var pt = briefLiquidStage.mapToItem(root.sharedBlurredBg, 0, 0);
                return Qt.vector4d(pt.x + _dep * 0.0, pt.y, 310, 240);
            }
            property vector4d colA_bg1: colorOsSwipeStage.sBg1(briefLiquidStage.topBriefCard)
            property vector4d colA_bg2: colorOsSwipeStage.sBg2(briefLiquidStage.topBriefCard)
            property vector4d colA_c1: colorOsSwipeStage.sC1(briefLiquidStage.topBriefCard)
            property vector4d colA_c2: colorOsSwipeStage.sC2(briefLiquidStage.topBriefCard)
            property vector4d colB_bg1: colorOsSwipeStage.sBg1(briefLiquidStage.underDeckCard)
            property vector4d colB_bg2: colorOsSwipeStage.sBg2(briefLiquidStage.underDeckCard)
            property vector4d colB_c1: colorOsSwipeStage.sC1(briefLiquidStage.underDeckCard)
            property vector4d colB_c2: colorOsSwipeStage.sC2(briefLiquidStage.underDeckCard)
            property var bgSource: root.sharedBlurredBg; fragmentShader: Qt.resolvedUrl("coloros_metaball.frag.qsb")
        }

          // Clipped bottom NowBar content: drops down from top (-28 -> 0) as the 34x34 circle re-inflates to 170x50!
          Item {
              id: botCircleClipBox
              width: briefLiquidStage.botW; height: briefLiquidStage.botH
              anchors.horizontalCenter: parent.horizontalCenter
              y: 200.0 - briefLiquidStage.botH * 0.5
              Rectangle { id: botCircleMask; anchors.fill: parent; radius: briefLiquidStage.botH * 0.5; visible: false; layer.enabled: true; layer.smooth: true }
              Item {
                  anchors.fill: parent; layer.enabled: true; layer.effect: OpacityMask { maskSource: botCircleMask }
                  PillCard {
                      x: (botCircleClipBox.width - 170) * 0.5
                      y: (botCircleClipBox.height - 50) * 0.5 + (root.briefExpanded ? 0.0 : -28.0 * briefLiquidStage.cBall)
                      card: briefLiquidStage.cbt < 0.48 ? briefLiquidStage.topBriefCard : briefLiquidStage.underDeckCard
                      contentOnly: true
                      opacity: Math.max(0.0, 1.0 - briefLiquidStage.cBall * 1.65)
                      extraContentBlur: briefLiquidStage.cBall * 12.0
                  }
              }
              MouseArea {
                  anchors.fill: parent; enabled: root.briefExpanded
                  onClicked: { haptics.buttonVibrate(); root.briefExpanded = false; }
              }
          }

          // Rising 282x92 Brief Sheet content emerging out of the 34x34 circle!
          Item {
              id: risingBriefContent
              width: 282; height: 92
              anchors.horizontalCenter: parent.horizontalCenter
              y: (120.0 + (80.0 + (-36.0 - 80.0) * briefLiquidStage.emergeT)) - 46.0
              opacity: Math.min(1.0, Math.max(0.0, (briefLiquidStage.emergeT - 0.36) / 0.54))
              scale: 0.72 + 0.28 * Math.max(0.0, briefLiquidStage.emergeT)
              readonly property real sheetBlur: Math.max(0.0, 1.0 - Math.max(0.0, briefLiquidStage.emergeT) * 1.12) * 14.0
              layer.enabled: sheetBlur > 0.3
              layer.effect: FastBlur { radius: risingBriefContent.sheetBlur; transparentBorder: true }

              ColumnLayout {
                  anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18; anchors.topMargin: 14; anchors.bottomMargin: 14; spacing: 3
                  RowLayout {
                      Layout.fillWidth: true
                      Text {
                          Layout.fillWidth: true
                          text: root.briefPeriod === "morning" ? "Good morning!" : (root.briefPeriod === "midday" ? "Good afternoon!" : (root.briefPeriod === "afternoon" ? "Good evening!" : "Good night!"))
                          color: "#FFFFFF"; font.family: "Google Sans Flex"; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight
                      }
                      Text {
                          text: Qt.formatTime(new Date(), "hh:mm")
                          color: Qt.rgba(1,1,1,0.68); font.family: "Google Sans Flex"; font.pixelSize: 12; font.weight: Font.Medium
                      }
                  }
                  Text {
                      Layout.fillWidth: true
                      text: "Vacoas-Phoenix · " + root.weatherTemp + "C " + root.weatherCond
                      color: Qt.rgba(1,1,1,0.82); font.family: "Google Sans Flex"; font.pixelSize: 12; font.weight: Font.Normal; elide: Text.ElideRight
                  }
                  Text {
                      Layout.fillWidth: true
                      text: root.customBriefSummary.length > 0 ? root.customBriefSummary : ("All caught up · Battery " + root.effectiveBatPercent + "%")
                      color: Qt.rgba(1,1,1,0.72); font.family: "Google Sans Flex"; font.pixelSize: 12; font.weight: Font.Normal; elide: Text.ElideRight
                  }
              }

              MouseArea {
                  anchors.fill: parent; enabled: root.briefExpanded
                  onClicked: { haptics.buttonVibrate(); root.briefExpanded = false; }
              }
          }
      }



    property real innerIconScale: 1.0
    property real innerTextScale: 1.0
    property real innerIconOffsetX: 0.0
    property real innerTextOffsetX: 0.0
    property real innerContentBlur: 0.0
    property real pillBreathScale: 1.0
    property string lastCardSig: ""
    property bool suppressNextActiveBounce: false

    ParallelAnimation {
        id: cardBounceAnim
        NumberAnimation { target: root; property: "innerIconScale"; from: 0.86; to: 1.0; duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.65 }
        NumberAnimation { target: root; property: "innerTextScale"; from: 0.93; to: 1.0; duration: 390; easing.type: Easing.OutBack; easing.overshoot: 1.35 }
        NumberAnimation { id: iconSlideAnim; target: root; property: "innerIconOffsetX"; to: 0.0; duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.45 }
        NumberAnimation { id: textSlideAnim; target: root; property: "innerTextOffsetX"; to: 0.0; duration: 410; easing.type: Easing.OutBack; easing.overshoot: 1.35 }
        NumberAnimation { target: root; property: "innerContentBlur"; from: 9.0; to: 0.0; duration: 250; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "pillBreathScale"; from: 1.026; to: 1.0; duration: 360; easing.type: Easing.OutBack; easing.overshoot: 1.35 }
    }

    function triggerCardBounce(enterFromSide) {
        if (root.flashlightExpanded || root.flashlightExpandT > 0.05) return;
        cardBounceAnim.stop();
        iconSlideAnim.from = enterFromSide * 8.5;
        textSlideAnim.from = enterFromSide * 14.0;
        cardBounceAnim.start();
    }

    onActiveCardChanged: {
        var sig = activeCard ? (activeCard.type + ":" + activeCard.label) : "";
        if (!colorOsSwipeStage.active && activeCard) root.restingCardSnapshot = root.cloneCard(activeCard, null);
        if (lastCardSig !== "" && sig !== lastCardSig && !colorOsSwipeStage.active && !root.suppressNextActiveBounce) {
            triggerCardBounce(0);
        }
        lastCardSig = sig;
    }

    Item {
        id: ballMorphStage
        anchors.fill: parent
        z: 22
        property bool active: false
        property int phase: 0        // 0 = shrink to 34x34 ball, 1 = expand to 170x50 pill + top-down slide
        property real morphT: 0.0    // 0.0 = 170x50 pill, 1.0 = 34x34 neutral ball
        property real dropY: 0.0
        property real contentBlur: 0.0
        property var fromCard: null
        property var toCard: null
        visible: active && !root.flashlightExpanded && root.flashlightExpandT < 0.02

        readonly property var curCard: phase === 0 ? fromCard : toCard
        readonly property real cm: Math.max(0.0, Math.min(1.0, morphT))
        readonly property real ballW: Math.max(30.0, 170.0 + (34.0 - 170.0) * morphT)
        readonly property real ballH: Math.max(30.0, 50.0 + (34.0 - 50.0) * cm)
        readonly property real ballR: ballH * 0.5

        SequentialAnimation {
            id: ballMorphSeq
            ParallelAnimation {
                NumberAnimation { target: ballMorphStage; property: "morphT"; from: 0.0; to: 1.0; duration: 170; easing.type: Easing.InOutCubic }
                NumberAnimation { target: ballMorphStage; property: "contentBlur"; from: 0.0; to: 12.0; duration: 130; easing.type: Easing.InCubic }
            }
            ScriptAction { script: { ballMorphStage.phase = 1; ballMorphStage.dropY = -30.0; } }
            PauseAnimation { duration: 28 }
            ParallelAnimation {
                NumberAnimation { target: ballMorphStage; property: "morphT"; from: 1.0; to: 0.0; duration: 355; easing.type: Easing.OutBack; easing.overshoot: 0.92 }
                NumberAnimation { target: ballMorphStage; property: "dropY"; from: -30.0; to: 0.0; duration: 375; easing.type: Easing.OutBack; easing.overshoot: 1.08 }
                NumberAnimation { target: ballMorphStage; property: "contentBlur"; from: 11.0; to: 0.0; duration: 260; easing.type: Easing.OutCubic }
            }
            ScriptAction { script: { ballMorphStage.active = false; ballMorphStage.phase = 0; ballMorphStage.morphT = 0.0; ballMorphStage.dropY = 0.0; } }
        }

        Canvas {
            visible: root.cards.length > 1 && ballMorphStage.cm < 0.65
            opacity: Math.max(0.0, 1.0 - ballMorphStage.cm / 0.65) * 0.44
            width: ballMorphStage.ballW + 40; height: 50; anchors.centerIn: parent
            onWidthChanged: if (visible) requestPaint()
            onVisibleChanged: if (visible) requestPaint()
            onPaint: {
                var ctx = getContext("2d"); ctx.reset();
                ctx.strokeStyle = "rgb(160, 175, 205)"; ctx.lineWidth = 3.2; ctx.lineCap = "round";
                var cxMid = width * 0.5; var cy = height * 0.5; var halfW = ballMorphStage.ballW * 0.5;
                ctx.beginPath(); ctx.arc(cxMid - (halfW + 5.25) + 32.0, cy, 32.0, Math.PI - 0.56, Math.PI + 0.56, false); ctx.stroke();
                ctx.beginPath(); ctx.arc(cxMid + (halfW + 5.25) - 32.0, cy, 32.0, -0.56, 0.56, false); ctx.stroke();
            }
        }

        Item {
            id: ballPillBox
            width: ballMorphStage.ballW; height: ballMorphStage.ballH; anchors.centerIn: parent
            Rectangle { id: ballMask; anchors.fill: parent; radius: ballMorphStage.ballR; visible: false; layer.enabled: true; layer.smooth: true }

            ShaderEffect {
                anchors.fill: parent
                property real progress: ballMorphStage.ballR
                property real dir: Math.min(1.0, ballMorphStage.cm * 1.85)
                property real passMode: 4.0
                property vector2d itemSize: Qt.vector2d(ballPillBox.width, ballPillBox.height)
                property vector2d screenSize: root.sharedBlurredBg ? Qt.vector2d(root.sharedBlurredBg.width, root.sharedBlurredBg.height) : Qt.vector2d(393, 852)
                property vector4d bgRect: {
                    var _dep = ballPillBox.width + ballPillBox.height + root.x + root.y;
                    if (!root.sharedBlurredBg) return Qt.vector4d((393 - width) * 0.5, 774, width, height);
                    var pt = ballPillBox.mapToItem(root.sharedBlurredBg, 0, 0);
                    return Qt.vector4d(pt.x + _dep * 0.0, pt.y, width, height);
                }
                readonly property real nf: 1.0 - ballMorphStage.cm
                property vector4d colA_bg1: { var c = Qt.color((ballMorphStage.curCard && ballMorphStage.curCard.bgC1) ? ballMorphStage.curCard.bgC1 : "#264EC9"); return Qt.vector4d(c.r, c.g, c.b, 0.14 * nf); }
                property vector4d colA_bg2: { var c = Qt.color((ballMorphStage.curCard && ballMorphStage.curCard.bgC2) ? ballMorphStage.curCard.bgC2 : "#1D3896"); return Qt.vector4d(c.r, c.g, c.b, (ballMorphStage.curCard && ballMorphStage.curCard.type === "flashlight") ? (2.0 * nf) : 1.0); }
                property vector4d colA_c1: { var c = Qt.color((ballMorphStage.curCard && ballMorphStage.curCard.c1) ? ballMorphStage.curCard.c1 : "#367DFF"); return Qt.vector4d(c.r, c.g, c.b, 0.16); }
                property vector4d colA_c2: { var c = Qt.color((ballMorphStage.curCard && ballMorphStage.curCard.c2) ? ballMorphStage.curCard.c2 : "#4000FF"); return Qt.vector4d(c.r, c.g, c.b, 0.15); }
                property vector4d colB_bg1: Qt.vector4d(0,0,0,0); property vector4d colB_bg2: Qt.vector4d(0,0,0,0)
                property vector4d colB_c1: colA_c1; property vector4d colB_c2: colA_c2
                property var bgSource: root.sharedBlurredBg; fragmentShader: Qt.resolvedUrl("coloros_metaball.frag.qsb")
            }

            Item {
                anchors.fill: parent; layer.enabled: true; layer.effect: OpacityMask { maskSource: ballMask }
                PillCard {
                    x: (ballPillBox.width - 170) * 0.5
                    y: (ballPillBox.height - 50) * 0.5 + (ballMorphStage.phase === 1 ? ballMorphStage.dropY : 0.0)
                    opacity: Math.max(0.0, 1.0 - ballMorphStage.cm * 1.65)
                    extraContentBlur: ballMorphStage.contentBlur
                    card: ballMorphStage.curCard; contentOnly: true
                }
            }
        }
    }

    function startDeckTransition(oldCard, newCard, popIn) {
        if (!oldCard || !newCard || root.flashlightExpanded || root.flashlightExpandT > 0.02) return;
        swipeCommitAnim.stop(); swipeCancelAnim.stop();
        colorOsSwipeStage.isForcedMode = false; colorOsSwipeStage.isSettleActive = false; colorOsSwipeStage.isDragActive = false;
        ballMorphSeq.stop();
        ballMorphStage.fromCard = oldCard; ballMorphStage.toCard = newCard;
        ballMorphStage.phase = 0; ballMorphStage.morphT = 0.0; ballMorphStage.dropY = 0.0; ballMorphStage.contentBlur = 0.0;
        ballMorphStage.active = true; ballMorphSeq.start();
    }

    Component.onCompleted: root.restingCardSnapshot = root.cloneCard(root.activeCard, null)

    PillCard {
        id: frontPillCard
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
        card: root.activeCard; interactiveCard: true; visible: card !== null
        opacity: (colorOsSwipeStage.active || ballMorphStage.visible) ? 0.0 : root.briefPillOpacity
        z: 20
        scale: root.briefExpanded ? 1.12 : (root.flashlightExpandT > 0.01 ? 1.0 : root.pillBreathScale)
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }


        MouseArea {
        id: collapsedPillTouchArea
        anchors.fill: parent; anchors.margins: -8; z: 25
        preventStealing: true
        enabled: !root.flashlightExpanded && root.flashlightExpandT < 0.05 && !root.briefExpanded && root.briefExpandT < 0.05
        visible: enabled
        property real pressX: 0
        property bool swiping: false
        property real lastX: 0
        property real lastTimestamp: 0
        property real velocity: 0 // px/ms

        onPressed: (mouse) => { 
            pressX = mouse.x; 
            lastX = mouse.x;
            lastTimestamp = Date.now();
            velocity = 0;
            swiping = false; 
            root.closeNotificationsRequested(); 
        }
        onPositionChanged: (mouse) => {
            var now = Date.now();
            var dt = Math.max(1, now - lastTimestamp);
            var dx_frame = mouse.x - lastX;
            var instantV = dx_frame / dt;
            velocity = (velocity * 0.4) + (instantV * 0.6);
            lastX = mouse.x;
            lastTimestamp = now;

            var dx = mouse.x - pressX;
            if (!swiping && Math.abs(dx) > 13 && root.cards.length > 1) {
                swiping = true; swipeCommitAnim.stop(); swipeCancelAnim.stop();
                root.briefExpanded = false; colorOsSwipeStage.isForcedMode = false; colorOsSwipeStage.isDragActive = true; colorOsSwipeStage.isSettleActive = false;
            }
            if (swiping) {
                colorOsSwipeStage.swipeDir = dx < 0 ? -1.0 : 1.0;
                colorOsSwipeStage.t = Math.max(0.0, Math.min(0.94, Math.abs(dx) / 124.0));
            }
        }
        onReleased: () => {
            if (swiping) {
                colorOsSwipeStage.isDragActive = false; 
                colorOsSwipeStage.isSettleActive = true;
                var v = Math.abs(velocity);
                swipeCommitAnim.duration = Math.max(220, Math.min(550, 800 / (v + 1.2)));
                swipeCommitAnim.easing.overshoot = Math.max(0.6, Math.min(1.8, v * 0.45 + 0.4));
                if (colorOsSwipeStage.t > 0.32 || v > 0.7) { 
                    haptics.buttonVibrate(); 
                    swipeCommitAnim.start(); 
                } else {
                    swipeCancelAnim.start();
                }
            } else {
                haptics.buttonVibrate();
                if (!root.activeCard) return;
                if (root.activeCard.type === "flashlight") root.flashlightExpanded = true;
                else if (root.activeCard.type === "brief") root.briefExpanded = true;
            }
        }
        onCanceled: if (swiping) { colorOsSwipeStage.isDragActive = false; colorOsSwipeStage.isSettleActive = true; swipeCancelAnim.start(); }
    }
}
