$(document).ready(function() {
	$("body").on('fileActionEvent', function(event, data) {
		if (data.obj.hasClass('disabled') || !data.obj.hasClass('dwnload')) return;
		if (data.obj.hasClass('listaction')) {
			var selrows = $("#fileList tr.selected.is-file:visible");
			var files = selrows.length>0 ? $.map(selrows, function(val,i) { return $(val).attr("data-file")}) : new Array(!data.file ? '' : data.file);
			file = files[0];
		} else {
			file = data.file;
		}
		var sep = window.location.pathname.lastIndexOf('/') + 1 == window.location.pathname.length ? '' : '/';
		window.location.href = window.location.pathname + sep + file;
	});
});