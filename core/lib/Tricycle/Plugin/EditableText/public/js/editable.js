/**
 * Created by Peter Bortchagovsky.
 * 22.03.13 3:48
 */

$(document).ready(function() {
	$('.editable_text').dblclick(function() {
		var $block = $(this);
		$block.data({old: $block.html()});
		$block.redactor({
			  focus: true
			, imageUpload: '/plugins/editable_text/upload_photos'
			, fileUpload: '/plugins/editable_text/upload_files'
			, imageGetJson: '/ajax/get_photos_list'
			, buttons: ['Exit', '|', '|',
				'|', 'html', '|', 'formatting', '|', 'bold', 'italic', 'alignment', 'deleted', '|', 'fontcolor', 'backcolor',
				'|', 'unorderedlist', 'orderedlist', 'outdent', 'indent',
				'|', 'image', 'file', 'table', 'link', 'horizontalrule',
				'|', 'Save']
			, buttonsCustom: {
				Exit : {
					title: 'Exit without saving'
					, callback: function() {
						$block.destroyEditor();
						$block.html($block.data('old'));
						$block.data({old: undefined});
					}
				},
				Save: {
					  title: 'Save'
					, callback: function(obj, event, key) {
						var html = obj.getCode();
						var text_id = $block.data('text_id');

						var settings = {
							  url: $block.data('specified_url') || '/plugins/editable_text'
							, method: 'POST'
							, data: {text: html, category_id: $block.data('category_id')}
						};
						if (text_id) {
							settings.method = 'PUT';
							settings.url += '/' + text_id;
						}

						AF.rest(settings).then(function(json) {
							if (json.status == 'ok') {
								if (!json.do_not_close_editor) {
									$block.destroyEditor();
									$block.data({old: undefined});
								} else {
									$block.data({old: json.new_text || html});
								}
								$block.html(json.new_text || html);
								if (json.new_id) $block.data({text_id: json.new_id});
							}
						});
					  }
				}
			}
		});
	});

	$('.editable_text[data-launched!=0]').dblclick();
});

