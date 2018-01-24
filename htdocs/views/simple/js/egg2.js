/*********************************************************************
(C) ZE CMS, Humboldt-Universitaet zu Berlin
Written by Daniel Rohde <d.rohde@cms.hu-berlin.de>
**********************************************************************
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
**********************************************************************/

function ColoredBlocks() {
	var self = this;
	self.height = 25;
	self.width = 25;
	self.startColors = 3;
	self.colors = self.getColorsCookie();
	
	var w = $(window);
	self.arena = {
		x : Math.round(w.width()*0.1),
		y : Math.round(w.height()*0.1),
		width : Math.round(w.width() * 0.8),
		height: Math.round(w.height() * 0.8),
		field : [],
		colors: ["black", "lightgray", "blue", "red", "cyan", "coral", "green", "magenta", "yellow", "lightgreen", "gold", "indigo", "gray"]
	};
	
	self.arena.bs = Math.floor(self.arena.width / self.width);
	self.arena.bs = Math.min( self.arena.bs, Math.floor(self.arena.height / self.height) );
	self.arena.width = self.arena.bs * self.width;
	self.arena.height = self.arena.bs * self.height;
	self.arena.x = Math.floor(w.width() - self.arena.width) / 2;
	self.arena.y = Math.floor(w.height() - self.arena.height ) / 2;
	
	self.arena.canvas = $("<canvas/>")
		.attr({tabindex : 0, width: self.arena.width, height: self.arena.height })
		.css({position: "fixed", left: self.arena.x + "px", top: self.arena.y + "px", cursor: "crosshair", zIndex: 10000})
		.on("keydown", function(event) { if (event.keyCode==27) self.destroy(); })
		.appendTo("body")
		.focus();
}
ColoredBlocks.prototype.start = function() {
	var self = this;
	self.blocks = self.width * self.height;
	self.points = 0;
	self.highscore = self.getHighscoreCookie();
	self.initField().draw().showGameInfo();
	self.arena.canvas.off("click.coloredblocks").on("click.coloredblocks", function(event) { self.click(event); })
	return self;
};
ColoredBlocks.prototype.destroy = function() {
	this.arena.canvas.remove();
	this.arena.pointsDiv.remove();
	this.arena.field = null;
};
ColoredBlocks.prototype.initField = function() {
	var self = this;
	for (var x = 0 ; x < self.width; x++ ) {
		self.arena.field[x] = [];
		for (var y = 0; y < self.height; y++ ) {
			self.arena.field[x][y] = Math.floor(Math.random() * self.colors);
		}
	}
	return self;
};
ColoredBlocks.prototype.draw = function() {
	var self = this;
	var ctx = self.arena.canvas[0].getContext("2d");
	ctx.save();
	ctx.clearRect(0,0,self.arena.width, self.arena.height);
	
	var a = self.arena;
	for (var x = 0 ; x < self.width; x++ ) {
		for (var y = 0; y < self.height; y++ ) {
			if (a.field[x][y] >= 0) {
				ctx.fillStyle = a.colors[a.field[x][y]];
				ctx.fillRect(x*a.bs, y*a.bs, a.bs, a.bs);
			}
		}
	}
	ctx.restore();
	return self;
};
ColoredBlocks.prototype.eliminate = function(x,y) {
	var self = this;
	var f = self.arena.field;
	var c = f[x][y];
	
	f[x][y] = -1;
	self.blocks -= 1;
	
	if (x>0 && f[x-1][y] == c) self.eliminate(x-1,y);
	if (x<self.width-1 && f[x+1][y] == c) self.eliminate(x+1,y);
	if (y>0 && f[x][y-1] == c) self.eliminate(x,y-1);
	if (y<self.height-1 && f[x][y+1] == c) self.eliminate(x,y+1);
	
	return self;
};
ColoredBlocks.prototype.isAllowed = function(x,y) {
	var self = this;
	if ( x<0 || x>=self.width || y<0 || y>=self.height) return false;
	var f = self.arena.field;
	var c = f[x][y];
	return c !== undefined
			&& c != -1
			&& ((x > 0 && f[x - 1][y] == c) || (x < self.width - 1 && f[x + 1][y] == c)
					|| (y > 0 && f[x][y - 1] == c) || (y < self.height - 1 && f[x][y + 1] == c));
};
ColoredBlocks.prototype.moveDown = function() {
	var self = this;
	var f = self.arena.field;
	var moved = false;
	for (var x =0 ; x<self.width; x++) {
		for (var y = self.height-1; y>=0; y--) {
			if (f[x][y] == -1 && f[x][y-1] != -1) {
				f[x][y] = f[x][y-1];
				f[x][y-1] = -1;
				moved = true;
			}
		}
	}
	return moved;
};
ColoredBlocks.prototype.isEmptyColumn = function(x) {
	return this.arena.field[x].reduce(function(a,b) { return a + (b !== undefined ? b : -1); },0) == -this.height;
};
ColoredBlocks.prototype.moveLeft = function() {
	var self = this;
	var moved = false;
	var f = self.arena.field;
	for (var x=0; x<self.width-1; x++ ) {
		if (self.isEmptyColumn(x) && !self.isEmptyColumn(x+1)) {
			for (var y = 0; y<self.height; y++) {
				f[x][y] = f[x+1][y];
				f[x+1][y] = -1;
			}
			moved = true;
		}
	}
	return moved;
};
ColoredBlocks.prototype.animate = function() {
	var self = this;
	while (self.moveDown() || self.moveLeft()) self.draw();
	return self.draw();
};
ColoredBlocks.prototype.isClickable = function() {
	var self = this;
	var clickable = false;
	for (var x = 0; x < self.width; x++) {
		for (var y = 0; y < self.height; y++) {
			if (self.isAllowed(x,y)) {
				clickable = true; 
				break;
			}
		}
		if (clickable) break;
	}
	return clickable;
};
ColoredBlocks.prototype.finish = function() {
	var self = this;
	if (!self.isClickable()) {
		self.arena.canvas.off("click.coloredblocks");
		if (self.blocks <= self.colors * 3) {
			self.colors = Math.min(self.colors + 1 , self.arena.colors.length);
		//} else if (self.blocks > self.colors * 4) {
		//	self.colors = Math.max(self.colors -1 , 1);
		}
		var ctx = self.arena.canvas[0].getContext("2d");
		ctx.save();
		var fontSize = 2.5 * self.arena.bs;
		var text ="FAILED!";
		ctx.font = fontSize+"px fantasy";
		if (self.points == self.highscore) {
			text = "!!! NEW HIGHSCORE !!!";
			ctx.fillStyle = "gold";
		} else if (self.colors > self.getColorsCookie() ) {
			text = "MORE COLORS: "+self.colors;
			ctx.fillStyle = "green";
		} else {
			ctx.fillStyle = "red";
		}
		var mt = ctx.measureText(text);
		ctx.fillText(text, (self.arena.width-mt.width) / 2, (self.arena.height-fontSize)/2 );
		ctx.restore();
		self.updateColorsCookie();
		window.setTimeout(function() {
			self.start();
		},5000);
		
	}
};
ColoredBlocks.prototype.calcPoints = function() {
	var self = this;
	self.points = ( (self.width * self.height) - self.blocks) * self.colors;
	return self;
};
ColoredBlocks.prototype.click = function(event) {
	var self = this;
	var offset = $(event.target).offset();
	var x = Math.floor( (event.pageX - offset.left) / self.arena.bs);
	var y = Math.floor( (event.pageY - offset.top) / self.arena.bs);
	if (self.mutex) return;
	self.mutex = true;
	if (self.isAllowed(x,y)) self.eliminate(x,y).animate().calcPoints().updateHighscore().showGameInfo().finish();
	self.mutex = false;
};
ColoredBlocks.prototype.showGameInfo = function() {
	var self = this;
	var a = self.arena;
	if (!a.pointsDiv) {
		var fs = a.bs/2;
		a.pointsDiv 
			= $("<div/>")
					.css(
						{ position: "fixed", display: "flex", flexFlow: "row nowrap", justifyContent: "space-between",
							left: a.x+"px", top: (a.y-(1.2*fs))+"px", 
							fontSize: fs+"px", height: "1.2em", lineHeight: 1.2,
							paddingLeft: fs+"px", paddingRight: fs+"px", width: (a.width-a.bs)+"px", zIndex: 10000, 
							backgroundColor: "black", color: "white", fontFamily: "monospace", fontWeight: "bold" 
						}
					)
					.appendTo("body")
					.append($("<div/>").html("&#8212; ColoredBlocks &#8212;"))
					.append($("<div/>").append($("<span/>").html("Colors: ")).append($("<span/>").addClass("colors")))
					.append($("<div/>").append($("<span/>").html("Blocks: ")).append($("<span/>").addClass("blocks")))
					.append($("<div/>").append($("<span/>").html("Points: ")).append($("<span/>").addClass("points")))
					.append($("<div/>").append($("<span/>").html("Highscore: ")).append($("<span/>").addClass("highscore")))
					;
	}
	function prependZeros(v,m) {
		var s = String(v);
		while (s.length <m) s = "0"+s;
		return s;
	}
	self.arena.pointsDiv.find(".colors").html(prependZeros(self.colors,2));
	self.arena.pointsDiv.find(".blocks").html(prependZeros(self.blocks,3));
	self.arena.pointsDiv.find(".points").html(prependZeros(self.points,5));
	self.arena.pointsDiv.find(".highscore").html(prependZeros(self.highscore,5));
	return self;
};
ColoredBlocks.prototype.getColorsCookie = function() {
	var c = document.cookie;
	var regex = /coloredblocks.colors=(\d+)/;
	var res = regex.exec(c);
	return !res || res.length === 0 ? this.startColors : parseInt(res[1]);
};
ColoredBlocks.prototype.updateColorsCookie = function() {
	document.cookie = "coloredblocks.colors="+this.colors+"; expires=Fri, 26 Feb 2027 00:00:00 UTC; path=/;";
	return this;
};

ColoredBlocks.prototype.getHighscoreCookie = function() {
	var c = document.cookie;
	var regex = /coloredblocks.highscore=(\d+)/;
	var res = regex.exec(c);
	return !res || res.length === 0 ? 0 : res[1];
};
ColoredBlocks.prototype.updateHighscore = function() {
	if (this.points > this.highscore) { 
		this.highscore = this.points;
		document.cookie = "coloredblocks.highscore="+this.highscore+"; expires=Fri, 26 Feb 2027 00:00:00 UTC; path=/;";
	}
	return this;
};
$("#flt").on("fileListChanged", function() {
	$("#clock").on("dblclick", function() {
		var cb = new ColoredBlocks();
		cb.start();
	});
});