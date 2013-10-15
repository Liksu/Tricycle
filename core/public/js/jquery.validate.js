/**
 * Created by Peter Bortchagovsky.
 * 25.03.13 02:21
 */

(function($) {
	/**
	 * validator(value to validate, param from data-validate, el) {
	 *   return true or error message
	 * }
	 */
	var validators = {
		required: function(val) {
			return val ? true : 'Required';
		},
		length: function(val, range) {
			range = $.map(range.split('..'), function(i) {return parseInt(i)});
			return val.length >= range[0] && val.length <= range[1] || 'Must be from ' + range[0] + ' to ' + range[1] + ' characters';
		},
		ajax: function(val, get_url, el) {
			var data = $(el).data('ajax');
			data.value = val;
			return $.getJSON(get_url, data).pipe(function(json) { return json.passed || json.error });
		}
	};

	function checker(val, name, param, el) {
		if (validators && validators[name] && typeof validators[name] == 'function') return validators[name](val, param, el);
		else return true;
	}

	function process(el, cb) {
		var value = '';
		if (el.tagName == 'INPUT') value = el.value;
		else value = el.innerHTML;

		var deferred = [];

		var check = $(el).data('validate').split(/;\s*/);                   // store raw checkers info: checker and their params
		for (var i = 0; i < check.length; i++) {                            // for each checker:
			if (/:/.test(check[i])) check[i] = check[i].split(/:\s*/);      //   replace checker name with array [checker {String}, params {String}]
			deferred.push(                                                  //   store result deferred
				$.when( checker.apply(undefined, [value].concat(check[i], [el])) )
			);
		}

		return $.when.apply(null, deferred).pipe(function() {
			var errors = [];
			for (var i = 0; i < arguments.length; i++) {
				if (arguments[i] !== true) errors.push( arguments[i] );
			}

			if (cb && typeof cb == 'function') cb(el, !errors.length, errors);  // call cb with checked element, boolean result (true == passed) and array of error strings
			return errors;
		});
	}

	/**
	 *
	 *  @param cb {Function} function(DOMElement, passed {Boolean}, errors {Array})
	 *  @param options {Object} validators extend
	 * @returns {boolean}
	 */
	$.fn.validate = function(cb, options) {
		if (!options && typeof cb == 'object') {
			options = cb;
			cb = $.noop;
		}
		$.extend(validators, options || {});

		var deferred = [];

		this.each(function() {
			if (this.tagName == 'FORM') {
				$('input[type!=submit][data-validate]', this).each(function(i, el) {
					deferred.push( process(el, cb) );
				});
			} else {
				if ( $(this).is('[data-validate]') ) deferred.push( process(this, cb) );
			}

		});

		return $.when.apply(null, deferred).pipe(function() {
			var passed = true;
			for (var i = 0; i < arguments.length; i++) {
				if (arguments[i].length) passed = false;
			}
			return passed;
		});
	};

})(jQuery);