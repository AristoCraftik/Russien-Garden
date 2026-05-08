class_name VoucherData
extends Resource

enum VoucherEffect {
	CAMERA_ZOOM_OUT
}

@export var voucher_id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var price: int = 100
@export var effect: VoucherEffect = VoucherEffect.CAMERA_ZOOM_OUT
@export var one_time: bool = false
