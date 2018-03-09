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
function Tetris() {
	return this;
}
Tetris.prototype.init = function(varsonly) {
	var self = this;
	self.tile = null;
	self.tiles = [ [[1,1,1,1]], [[1,1,1],[1,0,0]], [[1,0,0],[1,1,1]], [[1,1,1],[0,1,0]], [[1,1,0],[0,1,1]], [[0,1,1],[1,1,0]], [[1,1],[1,1]] ];
	self.tilequeue = [];
	self.level = 1;
	self.leveluplines = 20;
	self.speed = 500;
	self.speeddecr = 20; 
	self.score = 0;
	self.lines = 0;
	self.highscore = self.getHighscoreCookie();
	self.lost = false;
	
	if (!varsonly) {
		var $w = $(window);
		
		self.width = Math.floor($w.width() * 0.8);
		self.height = Math.floor($w.height() * 0.8);
		
		self.arena = {
				x : 0,
				y : 0,
				bs: 0,
				width : 12,
				height: 21,
				field : [],
				colors : [ "gray", "cyan", "orange", "blue", "purple", "red", "green", "yellow"]
		};
		self.arena.bs = Math.floor(Math.min(self.width / self.arena.width, self.height / self.arena.height ));
		
		
		self.arena.canvas = $("<canvas/>").attr({tabindex: 0, width: self.arena.width * self.arena.bs, height: self.arena.height * self.arena.bs})
		.css({ float: "right", backgroundColor: "black"});
		self.arena.ctx = self.arena.canvas[0].getContext("2d");

		self.next = $("<canvas/>").attr({width: (self.arena.bs * 4) +"px", height: (self.arena.bs * 4)+"px"}).css({ backgroundColor: "black", width: "50%", border: "4px solid black" });
		self.nextctx = self.next[0].getContext("2d");

		var width = 1.5 * self.arena.width * self.arena.bs;
		var height= self.arena.height * self.arena.bs;
		self.dialog = $("<div/>")
		.attr({tabindex:0})
		.css({ position: "fixed", top: ($w.height()-height)/2, left: ($w.width()-width)/2, width: width, height: height, "z-index": 10000, padding: "10px", 
			
			"background-color": "white", color: "black", boxShadow: "4px 4px 4px 2px rgba(0,0,0,0.5)", "font-family" : "monospace"})
		.append($("<div/>")
				.css({float: "left"})
				.html("<div style='font-weight:bold; font-size: 2em;'>Tetris</div>" +
						"<div style='margin: 10px 0;'>" +
						"<div>Highscore: <div style='display: inline-block' id='tetris-highscore'>"+self.zeros(self.highscore)+"</div></div><div>&nbsp;</div>" +
						"<div>Score: <div id='tetris-score' style='display:inline-block;'>00000</div></div>" +
						"<div>Level: <div id='tetris-level' style='display:inline-block;'>"+self.zeros(self.level)+"</div></div>" +
						"<div>Lines: <div style='display: inline-block' id='tetris-lines'>00000</div></div>" +
						
						"</div>")
				.append($("<div/>").html("Next:"))
				.append(self.next)
				.append($("<div/>").html("<div style='position:absolute;bottom:0;margin-bottom: 10px;'>Help:<div>p - Toggle pause</div><div>r - Start a new game</div>" +
						"<div>j, &larr; - Left</div><div>l, &rarr; - Right</div><div>k, &darr; - Rotate left</div>" +
						"<div>i, &uarr; - Rotate right</div><div> space, enter - Drop</div>" +
				"<div>Esc - Exit</div></div>"))
		)
		.append(self.arena.canvas)
		.on("keydown", function(event) { self.handleKeyboardInput(event); })
		.on("click mousemove wheel", function(event) { self.handleMouseInput(event); });
	}
	return self.setupField().deserialize().updateStats().drawNext();
};
Tetris.prototype.start = function() {
	var self = this;
	self.init().draw();
	self.dialog.appendTo($("body"));
	self.arena.canvas.focus();
	return self.gameLoop();
};
Tetris.prototype.restart = function() {
	return this.rmserialize().init(true).draw().toggleGameLoopOff(false).gameLoop();
};
Tetris.prototype.gameLoop = function() {
	var self = this;
	/*if (!self.dialog.is(":visible") || !self.arena.canvas.is(":visible")) {
		console.log("dialog or canvas is not visible!");
		window.clearInterval(self.visibleInterval);
		self.visibleInterval = window.setInterval(function() { self.gameLoop(); }, 50);
		return self;
	}*/
	if (self.interval) window.clearInterval(self.interval);
	self.interval = window.setInterval(function() {
		try {
			if (!self.gameLoopOff) self.move();
		} catch (e) {
			console.log(e);
		}
	}, self.speed);
	return self;
};
Tetris.prototype.drawNext = function() {
	var self = this;
	if (self.tilequeue.length <= 0) return self;
	var a = self.arena;
	var tile = self.tilequeue[0];
	var t = self.tiles[tile.t];
	self.nextctx.clearRect( 0,0, 4 * a.bs, 4 * a.bs );
	for (var y = 0; y < t.length; y++ ) {
		for (var x = 0; x < t[y].length; x++) {
			if (t[y][x] == 0) continue;
			var off = self.getTilePosOffsets(t, tile.o, x, y);
			self.drawTileXYC( self.nextctx, off[0], off[1], a.colors[tile.t + 1 ]);
		}
	}
	return self;
};
Tetris.prototype.updateStats = function() {
	var self = this;
	while ( (self.lines + 1 ) / self.leveluplines > self.level ) {
		self.level++;
		self.speed -= self.speeddecr;
		self.gameLoop();
	}
	self.updateHighscore();
	$("#tetris-level").html(self.zeros(self.level));
	$("#tetris-lines").html(self.zeros(self.lines));
	$("#tetris-score").html(self.zeros(self.score));
	$("#tetris-highscore").html(self.zeros(self.highscore));
	return self;
};
Tetris.prototype.zeros = function(v) {
	var s = ""+v;
	return "0".repeat(5-s.length)+s;
};
Tetris.prototype.toggleGameLoopOff = function(toggle) {
	var self = this;
	self.gameLoopOff = toggle === undefined ? ! self.gameLoopOff : toggle;
	return self;
};
Tetris.prototype.isGameLoopOff = function() {
	var self = this;
	return self.gameLoopOff;
};
Tetris.prototype.removeFullLines = function() {
	var self = this;
	var fullLines = [];
	var x,y;
	for (y = 0; y < self.arena.height - 1; y++) {
		var full = true;
		for (x = 1; x < self.arena.width - 1; x++) {
			full &= self.arena.field[x][y] > 0;
		}
		if (full) fullLines.push(y);
	}
	if (fullLines.length > 0) {
		self.lines += fullLines.length;
		var maxy = 0;
		for (var fli in fullLines) {
			var fl = fullLines[fli];
			maxy = Math.max(maxy, fl);
			for (y = fl; y > 0; y--) {
				for (x = 1; x < self.arena.width -1; x++) {
					self.arena.field[x][y] = self.arena.field[x][y-1];
				}
			}
		}
		self.draw(maxy);
	}
	return self;
};
Tetris.prototype.move = function() {
	var self = this;
	self.fillTileQueue().initTile();
	if (self.tile.y == -1 && !self.canMoveTile(self.tile, self.tile.x, self.tile.y, self.tile.o)) { // nothing moved but collision
		return self.finished();
	} else if (self.canMoveTile(self.tile, self.tile.x, self.tile.y+1, self.tile.o)) { // move one down
		self.drawTile(self.tile, true);
		self.tile.y++;
		self.drawTile(self.tile);
	} else {
		self.drawTile(self.tile, false, true).removeFullLines();
		self.score += 4 * self.level;
		self.tile = false;
	}
	self.updateStats().serialize();
	return self;
};
Tetris.prototype.getTileOrientation = function(o) {
	return o < 0 ? 3 : o > 3 ? 0 : o;
};
Tetris.prototype.handleKeyboardInput = function(event) {
	var self = this;
	if (event.preventDefault) event.preventDefault();
	if (event.keyCode == 27) self.serialize().destroy();
	else if (event.keyCode == 82) self.restart(); // 78:n, 82:r 
	else if (event.keyCode == 80) self.togglePause();
	else if (self.gameLoopOff) return self;
	else if (event.keyCode == 37 || event.keyCode == 74) self.moveTileTo(self.tile.x - 1, self.tile.o);
	else if (event.keyCode == 38 || event.keyCode == 73) self.moveTileTo(self.tile.x, self.getTileOrientation(self.tile.o + 1));
	else if (event.keyCode == 39 || event.keyCode == 76) self.moveTileTo(self.tile.x + 1, self.tile.o);
	else if (event.keyCode == 40 || event.keyCode == 75) self.moveTileTo(self.tile.x, self.getTileOrientation(self.tile.o - 1));
	else if (event.keyCode == 32 || event.keyCode == 13) self.dropTile();
	// else console.log(event.keyCode);
	return self;
};
Tetris.prototype.handleMouseInput = function(event) {
	var self = this;
	if (self.gameLoopOff) return self;
	var oe = event.originalEvent;
	if (event.type == "click") {
		if (event.preventDefault) event.preventDefault();
		if (event.which == 1) self.moveTileTo(self.tile.x, self.getTileOrientation(self.tile.o - 1));
		else if (event.which == 2) self.dropTile();
		else if (event.which == 3) self.moveTileTo(self.tile.x, self.getTileOrientation(self.tile.o + 1));
	}
	else if (event.type == "mousemove" && self.tile && event.originalEvent) {
		self.moveTileTo(self.tile.x + (Math.abs(oe.movementX) >= self.arena.bs/4 ? Math.sign(oe.movementX) : 0 ), self.tile.o);
	} 
	else if (event.type == "wheel") {
		self.moveTileTo(self.tile.x + Math.sign(oe.deltaX), self.getTileOrientation(self.tile.o + Math.sign(oe.deltaY)));
	}
	return self;
};
Tetris.prototype.togglePause = function(toggle) {
	var self = this;
	if (self.lost) return self;
	self.toggleGameLoopOff(toggle);
	if (self.isGameLoopOff()) {
		self.showMessageText("  PAUSED  ", "white", "green");
		if (self.tile) self.drawTile(self.tile, true);
	}
	else self.draw();
	return self;
};
Tetris.prototype.finished = function() {
	var self = this;
	self.lost = true;
	self.drawTile(self.tile, false, false);
	window.clearInterval(self.interval);
	self.rmserialize();
	if (self.score >= self.highscore) 
		self.showMessageText("  NEW HIGHSCORE  ", "yellow", "white");
	else 
		self.showMessageText("  LOST  ", "red","yellow");
	return self;
};
Tetris.prototype.moveTileTo = function(nx,no) {
	var self = this;
	if (self.canMoveTile(self.tile, nx, self.tile.y, no)) {
		self.drawTile(self.tile, true);
		self.tile.x=nx;
		self.tile.o=no;
		self.drawTile(self.tile);
	}
	return self;
};
Tetris.prototype.dropTile = function(sub) {
	var self = this;
	var tile = self.tile;
	self.toggleGameLoopOff(true);
	while (self.canMoveTile(tile, tile.x, tile.y+1, tile.o)) {
		self.drawTile(tile, true);
		tile.y++;
		self.drawTile(tile);
	}
	self.toggleGameLoopOff(false);
	return self;
};
Tetris.prototype.canMoveTile = function(tile, ntx, nty, nto) {
	var self = this;
	var f = self.arena.field;
	var t = self.tiles[tile.t];
	if (!t) return false;
	if (tile.x )
	for (var y = 0; y < t.length; y++) {  
		for (var x = 0; x < t[y].length; x++) {
			if (t[y][x] == 0) continue;
			var off = self.getTilePosOffsets(t, nto, x, y);
			if ( self.isPosInArena([ ntx + off[0], nty + off[1] ]) && f[ntx + off[0]][nty + off[1]] > 0) return false;
		} 
	}
	return true;
};
Tetris.prototype.initTile = function() {
	var self = this;
	if (!self.tile) {
		self.tile = self.tilequeue.shift();
		self.drawNext();
	}
	return self;
};
Tetris.prototype.getTilePosOffsets = function(t, o, x, y) {
	var fy = t.length-1, fx = t[y].length-1;
	return [ [x ,y], [fy-y, x], [fx-x, fy-y], [ y, fx-x] ][o];
};
Tetris.prototype.isPosInArena = function(pos) {
	return pos[0] >= 0 && pos[0] <= this.arena.width  && pos[1]>=0 && pos[1] <= this.arena.height;
};
Tetris.prototype.drawTile = function(tile, clear, put) {
	var self = this;
	var f = self.arena.field;
	var t = self.tiles[tile.t];
	for (var y = 0; y < t.length; y++) {
		for (var x = 0; x < t[y].length; x++) {
			if (t[y][x] == 0) continue;
			var off = self.getTilePosOffsets(t, tile.o, x, y);
			var pos = [ tile.x + off[0], tile.y + off[1] ];
			self.drawTileXYC(self.arena.ctx, pos[0],pos[1], clear ? 0 : self.arena.colors[tile.c-1]);
			if (put && self.isPosInArena(pos)) f[pos[0]][pos[1]] = clear ? 0 : tile.c;
		} 
	}
	return self;
};
Tetris.prototype.setupField = function() {
	var self = this;
	var a = self.arena;
	var f = a.field;
	for (var x = 0; x<a.width; x++ ) {
		f[x] = [];
		for (var y=0; y<a.height; y++) {
			f[x][y] = 0;
			f[0][y] = 1;
			if (x == a.width -1) f[a.width-1][y] = 1;
		}
		f[x][a.height-1] = 1;
	}
	return self;
};
Tetris.prototype.fillTileQueue = function() {
	var self = this;
	while (self.tilequeue.length < 3) {
		var t = Math.floor(Math.random()*self.tiles.length);
		self.tilequeue.push( { t: t, y: -1, x: Math.floor((self.arena.width - self.tiles[t][0].length) / 2), o : Math.floor(Math.random() * 4), c: t+2 });
	}
	return self;
};
Tetris.prototype.drawTileXYC = function(ctx, x,y,c) {
	var self = this;
	var bs = self.arena.bs;
	ctx.clearRect(x * bs, y * bs, bs, bs);
	if ( c != 0 ) {
		var sb = 1;
		var dsb = 2 * sb;
		//ctx.shadowColor = "white";
		//ctx.shadowBlur = 2;
		ctx.fillStyle = c;
		ctx.fillRect(x * bs + sb, y * bs + sb , bs - dsb , bs - dsb);
	}
	return self;
};
Tetris.prototype.draw = function(yoffset) {
	var self = this;
	var a = self.arena;
	var f = a.field;
	var starty = yoffset ? yoffset : a.height -1;
	for (var x = 0; x<a.width; x++) {
		for (var y = starty; y >=0; y--) {
			self.drawTileXYC(a.ctx, x,y, f[x][y] == 0 ? 0 : a.colors[f[x][y]-1]);
		}
	}
	return self;
};
Tetris.prototype.serialize = function() {
	var self = this;
	try {
		var state = {
				field: self.arena.field,
				level: self.level,
				speed: self.speed,
				lines: self.lines,
				tilequeue: self.tilequeue, 
				score: self.score, 
				tile: self.tile };
		document.cookie = "Tetris.state="+ btoa(JSON.stringify(state))+"; expires=Fri, 26 Feb 2027 00:00:00 UTC; path=/;";
	} catch (e) {
		console.log(e);
	}
	return self;
};
Tetris.prototype.rmserialize = function() {
	var self = this;
	document.cookie  = "Tetris.state=; expires=Thu, 01 Jan 1970 00:00:01 GMT; path=/;";
	return self;
};
Tetris.prototype.deserialize = function() {
	var self = this;
	var c = document.cookie;
	var regex = /Tetris.state=([^\;]+)/;
	var res = regex.exec(c);
	if ( res && res.length > 0 ) {
		try {
			var data = JSON.parse(atob(res[1]));
			self.arena.field = data.field;
			self.level = data.level;
			self.speed = data.speed;
			self.lines = data.lines;
			self.tilequeue = data.tilequeue;
			self.score = data.score;
			self.tile = data.tile;
			self.togglePause(true);
			return self;
		} catch (e) {
			console.log(e);
		}
	}
	return self;
};
Tetris.prototype.getHighscoreCookie = function() {
	var c = document.cookie;
	var regex = /Tetris.highscore=([^;]+)/;
	var res = regex.exec(c);
	return !res || res.length === 0 ? 0 : parseInt(atob(res[1]));
};
Tetris.prototype.updateHighscore = function() {
	var self = this;
	if (self.score > self.highscore) { 
		self.highscore = self.score;
		document.cookie = "Tetris.highscore="+btoa(self.highscore)+"; expires=Fri, 26 Feb 2027 00:00:00 UTC; path=/;";
	}
	return self;
};
Tetris.prototype.fitText = function(t, widthParam, heightParam) {
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
Tetris.prototype.showMessageText = function(text, color, stroke) {
	var self = this;
	var ctx = self.arena.ctx;
	window.setTimeout(function() {
		ctx.save();
		var w = self.arena.width  * self.arena.bs;
		var h = self.arena.height * self.arena.bs;
		var i = self.fitText(text, w, h);
		ctx.font = i.fs+"px fantasy";
		ctx.fillStyle = color;
		ctx.fillText(text, i.xOffset, i.yOffset, w);
		ctx.strokeStyle = stroke;
		ctx.strokeText(text, i.xOffset,i.yOffset, h);
		ctx.restore();	
	},50);
	return self;
};
Tetris.prototype.destroy = function() {
	var self = this;
	window.clearInterval(self.interval);
	self.dialog.remove();
	self.dialog = null;
	return self;
};
$("#now").on("dblclick", function() {
		var p = new Tetris();
		p.start();
});