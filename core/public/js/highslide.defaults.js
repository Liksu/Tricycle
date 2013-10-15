/**
 * Created by Peter Bortchagovsky.
 * 06.04.13 10:14
 */

hs.graphicsDir = '/img/highslide/';
hs.showCredits = false;
hs.outlineType = 'custom';
hs.registerOverlay({
	html: '<div class="closebutton" onclick="return hs.close(this)" title="Закрыть"></div>',
	position: 'top right',
	useOnHtml: true,
	fade: 2 // fading the semi-transparent overlay looks bad in IE
});

// Russian language strings
hs.lang = {
	cssDirection: 'ltr',
	loadingText: 'Загружается...',
	loadingTitle: 'Нажмите для отмены',
	focusTitle: 'Нажмите чтобы поместить на передний план',
	fullExpandTitle: 'Развернуть до оригинального размера',
	closeText: 'Закрыть',
	closeTitle: 'Закрыть (esc)',
	fullExpandText: 'Оригинальный размер',
	number: 'Изображение %1 из %2',
	restoreTitle: 'Нажмите чтобы закрыть изображение, нажмите и перетащите для изменения местоположения. Для просмотра изображений используйте стрелки.'
};
