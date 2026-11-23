/*
** Copyright (C) 2025 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtQuick.Controls.impl as CP
import Victron.VenusOS
import Victron.Gauges

Column {
	id: root

	property bool showFullDetails
	// MOD: true when more than one status ring is shown. Details stay visible, just with smaller fonts.
	property bool compact

	readonly property real _chargeCurrent: Global.system.battery.current
	readonly property bool _charging: !isNaN(_chargeCurrent) && _chargeCurrent > 0.1
	readonly property real _soc: Global.system.battery.stateOfCharge

	// MOD: estimated seconds until 100%, while current flows into the battery.
	// Uses Ah still to be put back (ConsumedAmphours) or, if unavailable, capacity x missing SoC.
	readonly property real _timeToFull: {
		if (!_charging || isNaN(_soc) || _soc >= 100) {
			return NaN
		}
		let ahToFull = NaN
		if (consumedAh.valid && consumedAh.value < 0) {
			ahToFull = -consumedAh.value
		} else {
			const cap = installedCapacity.valid ? installedCapacity.value
					: (capacity.valid ? capacity.value : NaN)
			if (!isNaN(cap) && cap > 0) {
				ahToFull = cap * (100 - _soc) / 100
			}
		}
		return isNaN(ahToFull) ? NaN : (ahToFull / _chargeCurrent) * 3600
	}

	readonly property bool _useTemperature: BackendConnection.portableIdInfo(centerService.value).type === "temperature"

	VeQuickItem {
		id: centerService
		uid: Global.systemSettings.serviceUid + "/Settings/Gui2/BriefView/CenterService"
	}

	VeQuickItem {
		id: activeBatteryService
		uid: Global.system.serviceUid + "/ActiveBatteryService"
	}

	readonly property string _batteryServiceUid: {
		if (!activeBatteryService.valid || AllDevicesModel.count === 0) {
			return ""
		}
		const info = BackendConnection.portableIdInfo(activeBatteryService.value)
		const device = AllDevicesModel.findDeviceWithTypeAndInstance(info.type, parseInt(info.instance))
		return device ? device.serviceUid : ""
	}

	VeQuickItem {
		id: consumedAh
		uid: root._batteryServiceUid ? root._batteryServiceUid + "/ConsumedAmphours" : ""
	}

	VeQuickItem {
		id: installedCapacity
		uid: root._batteryServiceUid ? root._batteryServiceUid + "/InstalledCapacity" : ""
	}

	VeQuickItem {
		id: capacity
		uid: root._batteryServiceUid ? root._batteryServiceUid + "/Capacity" : ""
	}

	VeQuickItem {
		id: temperature
		uid: {
			if (root._useTemperature) {
				const idInfo = BackendConnection.portableIdInfo(centerService.value)
				const device = Global.environmentInputs.model.deviceForDeviceInstance(idInfo.instance)
				if (device) {
					return device.serviceUid + "/Temperature"
				}
			}
			return ""
		}
		sourceUnit: Units.unitToVeUnit(VenusOS.Units_Temperature_Celsius)
		displayUnit: Units.unitToVeUnit(Global.systemSettings.temperatureUnit)
	}

	Row {
		anchors {
			horizontalCenter: parent.horizontalCenter
			horizontalCenterOffset: -(icon.width / 4) // cancel out the icon's internal whitespace
		}
		visible: root.showFullDetails

		CP.ColorImage {
			id: icon
			visible: !root.compact

			source: root._useTemperature ? "qrc:/images/icon_temp_32.svg" : Global.system.battery.icon
			color: Theme.color_font_primary
		}

		Label {
			// Keep the name bounding box inside the circle to avoid truncation
			width: Math.min(implicitWidth, 0.6 * (root.width - icon.width))
			anchors.verticalCenter: icon.verticalCenter
			minimumPixelSize: Theme.font_briefPage_battery_title_minimumPixelSize
			font.pixelSize: Theme.font_briefPage_battery_title_maximumPixelSize
			color: Theme.color_font_primary
			text: root._useTemperature ? CommonWords.temperature : CommonWords.battery
			fontSizeMode: Text.HorizontalFit
		}
	}

	FittedQuantityLabel {
		id: centerLabel
		anchors.horizontalCenter: parent.horizontalCenter
		width: parent.width - (2 * Theme.geometry_briefPage_centerGauge_centerText_horizontalSpacing)
		unit: root._useTemperature ? Global.systemSettings.temperatureUnit : VenusOS.Units_Percentage
		value: root._useTemperature ? (temperature.value ?? NaN) : Global.system.battery.stateOfCharge
		minimumPixelSize: Theme.font_briefPage_battery_percentage_minimumPixelSize
		maximumPixelSize: root.compact ? Theme.font_size_h3 : Theme.font_briefPage_battery_percentage_maximumPixelSize
	}

	Loader {
		width: parent.width
		height: active ? implicitHeight : 0
		active: root.showFullDetails && !root._useTemperature

		sourceComponent: Column {
			Row {
				anchors.horizontalCenter: parent.horizontalCenter
				spacing: root.compact ? Theme.geometry_briefPage_centerGauge_centerText_horizontalSpacing / 2
						: Theme.geometry_briefPage_centerGauge_centerText_horizontalSpacing

				QuantityLabel {
					valueColor: Theme.color_briefPage_battery_value_text_color
					unitColor: Theme.color_briefPage_battery_unit_text_color
					font.pixelSize: Theme.font_briefPage_battery_voltage_pixelSize
					unit: VenusOS.Units_Volt_DC
					value: Global.system.battery.voltage
				}

				ElectricalQuantityLabel {
					sourceType: VenusOS.ElectricalQuantity_Source_Dc
					dataObject: Global.system.battery
					valueColor: Theme.color_briefPage_battery_value_text_color
					unitColor: Theme.color_briefPage_battery_unit_text_color
					font.pixelSize: Theme.font_briefPage_battery_voltage_pixelSize
				}
			}

			Label {
				anchors.horizontalCenter: parent.horizontalCenter
				font.pixelSize: root.compact ? Theme.font_size_caption : Theme.font_briefPage_battery_timeToGo_pixelSize
				color: Theme.color_briefPage_battery_value_text_color
				text: root._charging
					  ? (isNaN(root._timeToFull) ? "" : Utils.secondsToString(root._timeToFull, false) + " to full")
					  : Utils.formatBatteryTimeToGo(Global.system.battery.timeToGo, VenusOS.Battery_TimeToGo_LongFormat)
				visible: text.length > 0
			}
		}
	}
}
