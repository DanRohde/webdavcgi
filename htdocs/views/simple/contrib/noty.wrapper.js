function noty(p) {
	if (p.type == "message") p.type="info";
	Noty.setMaxVisible(20);
	new Noty($.extend({ theme: "relax", progressBar : true, layout: "topCenter", timeout: 30000, closeWith: ["click", "button"] },p)).show();
}