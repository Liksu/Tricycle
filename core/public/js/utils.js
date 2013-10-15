/**
 * Created by Peter Bortchagovsky.
 * 23.03.13 13:55
 */

humane.error = humane.spawn({ addnCls: 'humane-libnotify-error', timeout: 3500 });
AF.query_error = function(msg) {
	if ( msg && msg.readyState && msg.status && msg.statusText ) msg = msg.statusText + '<br>code ' + msg.status;
	if ( msg && msg.readyState == 0 && msg.status == 0 && msg.statusText ) msg = null;
	humane.error(msg || 'Something wrong with query');
};

AF.rest = function(settings, cb) {
	$.extend(true, settings, {
		  type: settings.method
		, data: settings.data || settings
		, dataType: 'json'
		, error: AF.query_error
		, success: cb || settings.success || settings.cb || function(json) {
			if (json.status == 'error') {
				humane.error(json.message || 'Error');
			} else if (json.status == 'ok') {
				if (json.redirect) document.location = json.redirect;
				if (json.reload) document.location.reload();
				if (json.alert || settings.alert) humane.create({addnCls: 'humane-libnotify-success'}).log(json.message);
			}
		}
	});
	if (settings.fileUpload) $.extend(settings, {cache: false, contentType: false, processData: false});
	console.log('Send:', settings);

	return $.ajax(settings.url, settings);
};

AF.form = function(form_id, method, data_function, cb) {
	if (!data_function) data_function = function() {return {}};

	$('form[form_id=' + form_id + ']').unbind('submit').submit(function() {
		var $form = $(this);
		var settings = {
			  url: $form.attr('action')
			, method: method
			, data: data_function($form)
		};
		AF.rest(settings);
		return false;
	});
};

AF.link = function($obj, settings, url, cb) {
	if (typeof $obj == 'string') $obj = $($obj);
	if (!settings) settings = {};
	if (typeof settings == 'string') settings = {method: settings};
	if (!settings.method) settings.method = 'GET';
	if (!settings.url) settings.url = url || document.location;

	$obj.click(function(e) {
		AF.rest(settings, cb);
		return false;
	});
};

$.fn.set_val = function(val) {
	this.each(function() {
		if ($(this).is('input, select, textarea')) $(this).val(val);
		else $(this).html(val);

		if ($(this).is(':checkbox')) $(this).attr('checked', !!val);
	});
};

$.fn.serialize_to_params = function() {
	var params = {};
	this.each(function() {
		$.each( $(this).serializeArray(), function() {params[ this.name ] = this.value })
	});
	return params;
};
