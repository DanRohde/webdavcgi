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

function P2048() {
	var self = this;
	
	self.height = 4;
	self.width = 4;
	var w = $(window);
	self.arena = {
		x : Math.round(w.width()*0.1),
		y : Math.round(w.height()*0.1),
		width : Math.round(w.width() * 0.8),
		height: Math.round(w.height() * 0.8),
		border: 2,
		field : [],
		bgcolors : { 0: "#a9a9a9", 2: "#cccc99", 4: "#b3b300", 8: "#999900", 
					 16: "#808000", 32: "#666600", 64: "#cc2900", 128: "#b32400", 
					 256: "#991f00", 512: "#801a00", 1024: "#661400", 2048: "#ffd700",
					 4096: "#8800cc", 8192: "#7700b3", 16384: "#660099", 32768: "#550080",
					 65536: "#440066"}
	};

	self.arena.bs = Math.floor(self.arena.width / self.width);
	self.arena.bs = Math.min( self.arena.bs, Math.floor(self.arena.height / self.height) );
	self.arena.width = self.arena.bs * self.width;
	self.arena.height = self.arena.bs * self.height;
	self.arena.x = Math.floor(w.width() - self.arena.width) / 2;
	self.arena.y = Math.floor(w.height() - self.arena.height ) / 2;
		
	self.arena.canvas = $("<canvas/>")
		.attr({tabindex : 0, width: self.arena.width, height: self.arena.height })
		.css({position: "fixed", left: self.arena.x + "px", top: self.arena.y + "px", cursor: "move", zIndex: 10000})
		.on("keydown", function(event) { if (event.keyCode==27) self.destroy(); })
		.appendTo("body")
		.focus();
	return self;
}

P2048.prototype.start = function() {
	var self = this;

	self.won = false;
	self.failed = false;

	self.arena.canvas
		.off("mousedown.r2048").on("mousedown.r2048", function(event) { self.mousedown(event); })
		.off("mousemove.r2048").on("mousemove.r2048", function(event) { self.mousemove(event); })
		.off("mouseup.r2048").on("mouseup.r2048", function(event) { self.mouseup(event); })
		.off("click.r2048").on("click.r2048", function(event){ self.click(event); })
		.off("keydown.r2048").on("keydown.r2048", function(event) { self.keypressed(event);})
	;
	self.score = 0;
	self.countNums = 0;
	self.highscore = self.getHighscoreCookie();
	self.arena.ctx = self.arena.canvas[0].getContext("2d");
	if (!self.deserialize()) {
		self.initField().addNumber().addNumber().serialize();
	}
	self.draw().showGameInfo();

	return self;
};
P2048.prototype.destroy = function() {
	this.arena.canvas.remove();
	this.arena.scoreDiv.remove();
	this.arena.field = null;
};
P2048.prototype.mousedown = function(event) {
	var self = this;
	self.arena.mousepos = { x: event.pageX, y: event.pageY};
	self.arena.dragging = false;
};
P2048.prototype.mousemove = function(event) {
	var self = this;
	this.arena.canvas.css("cursor",this.getMouseDirInfo(event).cursor);
	if (!self.arena.mousepos) return;
	if (self.arena.mousepos.x != event.pageX || self.arena.mousepos.y != event.pageY ) {
		self.arena.dragging = true;
	}
};
P2048.prototype.mouseup = function(event) {
	var self = this;
	if (self.arena.dragging) {
		var diffX = event.pageX - self.arena.mousepos.x;
		var diffY = event.pageY - self.arena.mousepos.y;
		if (Math.abs(diffX) > Math.abs(diffY)) { // left or right
			if (diffX < 0) self.move(-1,0); else self.move(1,0);
		} else { // up or down
			if (diffY < 0) self.move(0,-1); else self.move(0,1);
		}
		self.arena.dragging = false;
	}
};
P2048.prototype.getMouseDirInfo = function(event) {
	var self = this;
	var offset = $(event.target).offset();
	var x = Math.floor( (event.pageX - offset.left) / self.arena.bs);
	var y = Math.floor( (event.pageY - offset.top) / self.arena.bs);
	var dirinfo =  { dir : { x: 0, y: 0}, cursor : "move"};
	if (y>0 && y<self.height-1) {
		if ( x === 0 ) dirinfo = {dir:{x:-1, y:0}, cursor:"w-resize"};
		else if ( x == self.width-1 ) dirinfo = {dir:{x:1,y:0},cursor:"e-resize"};
	}
	if (x>0 && x<self.width-1) {
		if ( y === 0 ) dirinfo = {dir:{x:0,y:-1},cursor:"n-resize"};
		else if ( y == self.height-1) dirinfo = {dir:{x:0,y:1},cursor:"s-resize"};
	}
	return dirinfo;
};
P2048.prototype.click = function(event) {
	var self = this;
	if (self.arena.dragging) return self;
	var i = self.getMouseDirInfo(event);
	if (i.dir.x !=0 || i.dir.y !=0 ) self.move(i.dir.x,i.dir.y);
	return self;
};
P2048.prototype.keypressed = function(event) {
	var self = this;
	if (event.keyCode == 37) self.move(-1,0); // left
	else if (event.keyCode == 38) self.move(0,-1); // up
	else if (event.keyCode == 39) self.move(1,0); // right
	else if (event.keyCode == 40) self.move(0,1); // down
	else if (event.keyCode == 82 || event.keyCode == 78) self.rmserialize().start(); // restart ('n' or 'r')
};
P2048.prototype.initField = function() {
	var self = this;
	for (var x = 0 ; x < self.width; x++ ) {
		self.arena.field[x] = [];
		for (var y = 0; y < self.height; y++ ) {
			self.arena.field[x][y] = 0; //Math.pow(2, (y*self.width)+x+1);
		}
	}
	return self;
};
P2048.prototype.fitText = function(t, widthParam, heightParam) {
	var self = this;
	var a = self.arena;
	var w = widthParam || a.bs;
	var h = heightParam || a.bs;
	var ctx = a.ctx;
	if (!self.fitTextCache) self.fitTextCache = {};
	if (self.fitTextCache[t]) return self.fitTextCache[t];
	var decr = 1;
	var fs = Math.floor(h*0.8);
	var tw;
	do {
		fs -= decr;
		ctx.font = fs + "px fantasy";
		tw = ctx.measureText(t).width;
	} while ( tw >= w || fs >= h );
	return self.fitTextCache[t] = {
		fs: fs,
		xOffset: Math.floor((w-tw)/2),
		yOffset: Math.floor(fs + ((h-fs)/2))
	};
};
P2048.prototype.fillRect = function(x,y,w,h,cp,rp) {
	var self = this;
	var c = cp || "gold";
	var r = rp || Math.min(w/10,h/10);
	if (w < 2 * r) r = w / 2;
	if (h < 2 * r) r = h / 2;
	var ctx = self.arena.ctx;
	ctx.beginPath();
	ctx.moveTo(x + r, y);
	ctx.arcTo(x + w, y, x + w, y + h, r);
	ctx.arcTo(x + w, y + h, x, y + h, r);
	ctx.arcTo(x, y + h, x, y, r);
	ctx.arcTo(x, y, x + w, y, r);
	ctx.closePath();
	ctx.fillStyle = c;
	ctx.fill();
	return self;
};
P2048.prototype.getColors = function(v) {
	var self = this;
	return { fg: "white" , bg: self.arena.bgcolors[v]  };
};
P2048.prototype.drawNumber = function(x, y) {
	var self = this;
	var a = self.arena;
	var v = a.field[x][y];
	var ctx = a.ctx;
	var bx = x * a.bs + a.border;
	var by = y * a.bs + a.border;
	var bs = a.bs - 2*a.border;
	var i = self.fitText(v);

	var c = self.getColors(v);
	ctx.clearRect(bx,by,bs,bs);
	self.fillRect(bx,by,bs,bs,c.bg);

	if (v > 0) {
		ctx.font = i.fs+"px fantasy";
		ctx.fillStyle = c.fg;
		ctx.fillText(v, bx + i.xOffset , by + i.yOffset, bs);
	}
	return self;
};
P2048.prototype.draw = function() {
	var self = this;
	var a = self.arena;
	var ctx = a.ctx;
	ctx.save();
	ctx.clearRect(0,0,a.width,a.height);
	for (var x = 0; x < self.width; x++) {
		for (var y = 0; y < self.height; y++) {
			var v = a.field[x][y];
			self.drawNumber(x, y);
		}
	}
	ctx.restore();
	return self;
};
P2048.prototype.hasFree = function() {
	var self = this;
	var f = self.arena.field;
	for (var x = 0; x<self.width; x++) {
		for (var y = 0; y<self.height; y++) {
			if (f[x][y] === 0) return true;
		}
	}
	return false;
};
P2048.prototype.hasMoveable = function() {
	var self = this;
	var f = self.arena.field;
	for (var x=0; x<self.width; x++) {
		for (var y=0; y<self.height; y++) {
			if (f[x][y] == 0  // empty field
					|| (x+1<self.width  && f[x][y] == f[x+1][y]) // right neighbor 
					|| (y+1<self.height && f[x][y] == f[x][y+1]) // lower neighbor
				) 
				return true;
		}
	}
	return false;
};
P2048.prototype.getFree = function() {
	var self = this;
	var f = self.arena.field;
	var free = [];
	for (var x=0; x<self.width; x++) {
		for (var y=0; y<self.height; y++) {
			if (f[x][y] === 0) free.push([x,y]);
		}
	}
	return free;
};
P2048.prototype.addNumber = function() {
	var self = this;
	var free = self.getFree();
	var xy = free[Math.floor(Math.random() * free.length)];
	if (!self.countNums) self.countNums = 0;
	self.countNums+=1;
	self.arena.field[xy[0]][xy[1]] = self.countNums < 4 ? 2 : 4;
	window.setTimeout(function() {
		self.drawNumber(xy[0],xy[1]);
	}, 300);
	if (self.countNums > 4) self.countNums = 0;
	return self;
};
P2048.prototype.inRange = function(x,y) {
	return x>=0 && x<this.width && y>=0 && y<this.height;
};
P2048.prototype.move = function(dirX,dirY, levelParam) {
	var level = levelParam || 1;
	var self = this;
	var moved = 0;
	var f = self.arena.field;
	if ( (level == 1 && self.moving) || self.failed ) return self;
	self.moving = true;
	
	// first remove spaces:
	var x,y;
	x = dirX <= 0 ? 0 : self.width - 1;
	while (x>=0 && x<self.width) {
		y = dirY <= 0 ? 0 : self.height - 1;
		while (y>=0 && y<self.height) {
			if (f[x][y] != 0 && self.inRange(x+dirX,y+dirY) && f[x+dirX][y+dirY] == 0) {
				f[x+dirX][y+dirY]=f[x][y];
				f[x][y]=0;
				self.drawNumber(x,y);
				self.drawNumber(x+dirX,y+dirY);
				moved+=1;
			}
			y += dirY <= 0 ? 1 : -1;
		}
		x += dirX <= 0 ? 1 : -1;
	}
	if (moved > 0) moved += self.move(dirX,dirY,level+1);
	if (level > 1) return moved;
	// now add:
	x = dirX <= 0 ? 0 : self.width - 1;
	while (x>=0 && x<self.width) {
		y = dirY <= 0 ? 0 : self.height - 1;
		while (y>=0 && y<self.height) {
			if (f[x][y] != 0 && self.inRange(x+dirX,y+dirY) && f[x+dirX][y+dirY] == f[x][y]) {
				self.score += f[x+dirX][y+dirY]+=f[x][y];
				f[x][y]=0;
				self.drawNumber(x,y);
				self.drawNumber(x+dirX,y+dirY);
				moved+=1;
			}
			y += dirY <= 0 ? 1 : -1;
		}
		x += dirX <= 0 ? 1 : -1;
	}
	// remove spaces again:
	moved+=self.move(dirX,dirY, level+1);
	if (moved > 0) {
		self.updateHighscore().showGameInfo().addNumber();
	}
	self.checkGameState();
	self.moving = false;
	return self;
};
P2048.prototype.hasWon = function() {
	var self = this;
	for (var x = 0; x<self.width; x++) {
		for (var y=0; y<self.height; y++) {
			if (self.arena.field[x][y] >= 2048) return true;
		}
	}
	return false;
};
P2048.prototype.showMessageText = function(text, color, stroke) {
	var self = this;
	var ctx = self.arena.ctx;
	window.setTimeout(function() {
		ctx.save();
		var i = self.fitText(text, self.arena.width, self.arena.height);
		ctx.font = i.fs+"px fantasy";
		ctx.fillStyle = color;
		ctx.fillText(text, i.xOffset, i.yOffset, self.arena.width);
		ctx.strokeStyle = stroke;
		ctx.strokeText(text, i.xOffset,i.yOffset,self.arena.width);
		ctx.restore();	
	},300);
	return self;
};
P2048.prototype.checkGameState = function() {
	var self = this;
	if (self.hasWon() && !self.won) {
		self.won = true;
		self.showMessageText( "WINNER!", "gold","red");
		window.setTimeout(function() { self.draw(); }, 5000);
	} else if (!self.hasMoveable()) {
		if (self.score >= self.highscore)
			self.showMessageText("!!! NEW HIGHSCORE !!!", "gold","red");
		else 
			self.showMessageText("FAILED!", "red", "black");
		self.failed = true;
		self.rmserialize();
		window.setTimeout(function() { self.start(); }, 5000);
	} else {
		self.serialize();
	}
	return self;
};
P2048.prototype.getHighscoreCookie = function() {
	var c = document.cookie;
	var regex = /p2048.highscore=(\d+)/;
	var res = regex.exec(c);
	return !res || res.length === 0 ? 0 : res[1];
};
P2048.prototype.updateHighscore = function() {
	if (this.score > this.highscore) { 
		this.highscore = this.score;
		document.cookie = "p2048.highscore="+this.highscore+"; expires=Fri, 26 Feb 2027 00:00:00 UTC; path=/;";
	}
	return this;
};
P2048.prototype.prependZeros = function(v,m) {
	var s = String(v);
	while (s.length <m) s = "0"+s;
	return s;
};
P2048.prototype.showGameInfo = function() {
	var self = this;
	var a = self.arena;
	if (!a.scoreDiv) {
		var fs = a.bs/8;
		a.scoreDiv 
			= $("<div/>")
					.css(
						{ position: "fixed", display: "flex", flexFlow: "row nowrap", justifyContent: "space-between",
							left: a.x+"px", top: (a.y-(1.2*fs))+"px", 
							fontSize: fs+"px", height: "1.2em", lineHeight: 1.2,
							paddingLeft: fs+"px", paddingRight: fs+"px", width: (a.width-2*fs)+"px", zIndex: 10000, 
							backgroundColor: "black", color: "white", fontFamily: "monospace", fontWeight: "bold" 
						}
					)
					.appendTo("body")
					.append($("<div/>").html("&#8212; 2048 &#8212;"))
					.append($("<div/>").append($("<span/>").html("Best: ")).append($("<span/>").addClass("highscore")))
					.append($("<div/>").append($("<span/>").html("Score: ")).append($("<span/>").addClass("score")))
					;
	}
	
	self.arena.scoreDiv.find(".score").html(self.prependZeros(self.score,6));
	self.arena.scoreDiv.find(".highscore").html(self.prependZeros(self.highscore,6));
	return self;
};
P2048.prototype.serialize = function() {
	var self = this;
	document.cookie = "p2048.state="+ JSON.stringify(self.arena.field)+"; expires=Fri, 26 Feb 2027 00:00:00 UTC; path=/;";
	return self;
};
P2048.prototype.rmserialize = function() {
	var self = this;
	document.cookie  = "p2048.state=; expires=Thu, 01 Jan 1970 00:00:01 GMT; path=/;";
	return self;
};
P2048.prototype.deserialize = function() {
	var self = this;
	var c = document.cookie;
	var regex = /p2048.state=([^\;]+)/;
	var res = regex.exec(c);
	if ( res && res.length > 0 ) {
		try {
			self.arena.field = JSON.parse(res[1]);
			return true;
		} catch (e) {
			console.log(e);
		}
	}
	return false;
};
$("#flt").on("fileListChanged", function() {
	$(".ai-create-file.filestats-filecount").on("dblclick", function() {
		var p = new P2048();
		p.start();
	});
});