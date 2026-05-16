/**
 * screen-watermark@bootc.local
 *
 * Persistent tiled diagonal watermark that overlays every monitor with:
 *   <username>  ·  <hostname>  ·  <login date/time>
 *
 * Compatible with GNOME Shell 45+ (ESM / class-based extension API).
 */

import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function buildWatermarkText() {
    const user = GLib.get_user_name() || 'unknown';
    const host = GLib.get_host_name() || 'unknown';

    let dateStr;
    try {
        const dt = GLib.DateTime.new_now_local();
        dateStr = dt.format('%Y-%m-%d %H:%M');
    } catch (_) {
        dateStr = new Date().toLocaleString();
    }

    return `${user}  ·  ${host}  ·  ${dateStr}`;
}

// ---------------------------------------------------------------------------
// WatermarkOverlay — one full-monitor overlay per physical display
// ---------------------------------------------------------------------------

// Explicit GTypeName prevents collisions when the extension is reloaded.
const WatermarkOverlay = GObject.registerClass({
    GTypeName: 'ScreenWatermarkOverlay',
}, class WatermarkOverlay extends St.Widget {

    _init(monitorIndex, text) {
        super._init({
            reactive:  false,
            can_focus: false,
            opacity:   0,
        });

        this._monitorIndex = monitorIndex;
        this._text = text;
        this._buildTile();
    }

    _buildTile() {
        const monitor = Main.layoutManager.monitors[this._monitorIndex];
        if (!monitor) return;

        const { width, height } = monitor;

        const SPACING_X    = 650;
        const SPACING_Y    = 320;
        const ROTATION_DEG = -35;
        const PAD          = 600;
        const OPACITY_LIGHT = 0.09;
        const OPACITY_DARK  = 0.18;

        let labelCount = 0;

        for (let y = -PAD; y < height + PAD; y += SPACING_Y) {
            const rowOffset = (Math.floor(y / SPACING_Y) % 2 === 0) ? 0 : SPACING_X / 2;

            for (let x = -PAD + rowOffset; x < width + PAD; x += SPACING_X) {
                // Alternate opacity: even labels are light, odd labels are dark
                const opacity = (labelCount % 2 === 0) ? OPACITY_LIGHT : OPACITY_DARK;
                labelCount++;

                const label = new St.Label({
                    text:        this._text,
                    style_class: 'watermark-label',
                    reactive:    false,
                    opacity:      Math.round(255 * opacity),
                });

                label.set_pivot_point(0.5, 0.5);
                // Use the rotation_angle_z property directly —
                // Clutter.RotateAxis was removed in Clutter 12+ / GNOME 45+.
                label.rotation_angle_z = ROTATION_DEG;
                label.set_position(x, y);

                this.add_child(label);
            }
        }
    }

    fadeIn() {
        this.ease({
            opacity:  255,
            duration: 1200,
            mode:     Clutter.AnimationMode.EASE_OUT_QUAD,
        });
    }
});

// ---------------------------------------------------------------------------
// Extension entry-point
// ---------------------------------------------------------------------------

export default class ScreenWatermarkExtension extends Extension {

    enable() {
        this._watermarkText = buildWatermarkText();
        this._overlays = [];

        this._buildOverlays();

        this._monitorsChangedId = Main.layoutManager.connect(
            'monitors-changed',
            () => this._rebuildOverlays()
        );
    }

    disable() {
        if (this._monitorsChangedId) {
            Main.layoutManager.disconnect(this._monitorsChangedId);
            this._monitorsChangedId = null;
        }
        this._destroyOverlays();
        this._watermarkText = null;
    }

    // -----------------------------------------------------------------------

    _buildOverlays() {
        for (let i = 0; i < Main.layoutManager.monitors.length; i++) {
            const monitor = Main.layoutManager.monitors[i];

            const overlay = new WatermarkOverlay(i, this._watermarkText);
            overlay.set_position(monitor.x, monitor.y);
            overlay.set_size(monitor.width, monitor.height);

            // Add to the top of uiGroup so the watermark sits above the
            // wallpaper/desktop but input events still fall through (reactive: false).
            Main.uiGroup.add_child(overlay);

            overlay.fadeIn();
            this._overlays.push(overlay);
        }
    }

    _destroyOverlays() {
        for (const overlay of this._overlays) {
            // Explicitly remove from parent before destroy to avoid stale references.
            if (overlay.get_parent())
                Main.uiGroup.remove_child(overlay);
            overlay.destroy();
        }
        this._overlays = [];
    }

    _rebuildOverlays() {
        this._destroyOverlays();
        this._buildOverlays();
    }
}
