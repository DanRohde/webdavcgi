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

function Snake() {
	this.level = 1;
	this.levelup = 1000; 
	this.levelupFactor = 1000;
	this.speed = 400;
	this.speedIncr = 20;
	this.points = 0;
	this.feedFactor = 100; // points+= feedFactor * level for feed
	this.stepFactor = 10; // points = stepFactor * level for every move
	this.segFactor = 5; // new snake segments = segFactor * level
	this.eat = [ {s: this.segFactor, c: "rgba(0,255,0,0.5)"} ]; // array of { s: segments, c: color }
	this.snake = [ [2,1,"rgba(0,0,255,0.5)"], [1,1,-1] ];
	this.dir = { x: 1, y: 0 };
	this.wall = {};
	this.feed = {};
	this.elements = 60; // elements in a row 
	this.highscore = this.getHighscoreCookie();
	this.steps = 0;
	this.imagesLoaded = 0;
	this.imageCount = 2;
	this.imagesLoadedFunc = function() { this.self.imagesLoaded++; if (this.self.imagesLoaded == this.self.imageCount) this.self.startLoop();};
	this.egg = new Image();
	this.egg.src = "data:image/svg+xml;utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20height%3D%221e3%22%20width%3D%221e3%22%20version%3D%221.1%22%20viewBox%3D%220%200%20264.58333%20264.58334%22%3E%3Cpath%20stroke-width%3D%22.29342%22%20fill%3D%22%23FFFFFF%22%20d%3D%22m132.29%2035.305c-41.949%200-75.956%2061.073-75.956%20114.64s34.006%2079.337%2075.956%2079.337c41.949%200%2075.956-25.77%2075.956-79.337%200-53.564-34.006-114.64-75.956-114.64zm-1.2806%2016.171c14.65-0.1561%2027.215%2010.303%2035.808%2021.389%2019.171%2027.183%2030.099%2062.507%2023.415%2095.587-3.0109%2023.503-24.037%2041.645-47.119%2044.426-22.659%203.7226-49.064-4.519-61.581-24.733-15.155-29.53-9.9535-65.29%203.757-94.273%208.7206-18.859%2022.905-39.235%2045.021-42.38%200.23283-0.0079%200.46566-0.01323%200.69849-0.01587z%22%2F%3E%3C%2Fsvg%3E";
	this.egg.self = this;
	this.egg.onload = this.imagesLoadedFunc;
	this.brick = new Image();
	this.brick.src = 'data:image/svg+xml;utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20height%3D%221e3%22%20width%3D%221e3%22%20version%3D%221.1%22%20viewBox%3D%220%200%20264.58333%20264.58334%22%3E%3Cg%20transform%3D%22translate%280%20-32.417%29%22%3E%3Cpath%20d%3D%22m-0.35547%200v60.652h660.4v379.02h-660.4l0.00453%20120.66h321.15v379.02h-321.15l0.00453%2060.65h321.15%20120.66%20558.95v-60.65h-558.95v-379.02h558.95v-120.66h-219.7v-379.02l219.7%200.002v-60.652h-1000.8z%22%20transform%3D%22matrix%28.26458%200%200%20.26458%200%2032.417%29%22%20fill%3D%22%23FFFFFF%22%2F%3E%3C%2Fg%3E%3C%2Fsvg%3E';
	this.brick.self = this;
	this.brick.onload = this.imagesLoadedFunc;
	var w = $(window);
	this.arena = {
		x : Math.round(w.width()*0.1),
		y : Math.round(w.height()*0.1),
		width : Math.round(w.width() * 0.8),
		height: Math.round(w.height() * 0.8)
	};
	
	this.seg = Math.floor(this.arena.width  / this.elements); // element size in pixel
	this.maxX = this.elements;
	this.maxY =  Math.floor(this.arena.height / this.seg);
	this.arena.width = this.maxX * this.seg;
	this.arena.height = this.maxY * this.seg;
}
Snake.prototype.start = function() {
	var self = this;
	self.arena.canvas = $("<canvas/>")
		.attr({tabindex : 0, width: self.arena.width, height: self.arena.height })
		.css({position: "fixed", left: self.arena.x + "px", top: self.arena.y + "px", cursor: "crosshair", zIndex: 10000})
		.appendTo("body")
		.on("click.snake", function(event) {
			var i = self.getSnakeInfo();
			var offset = $(this).offset();
			var cx = event.pageX - offset.left;
			var cy = event.pageY - offset.top;
			if (self.dir.x != 0) self.setDir(0, cy > i.py ? 1 : -1); // left - right
			else if (self.dir.y != 0) self.setDir(cx > i.px ? 1 : -1, 0); // up - down
		})
		.focus();
	$("body").on("keydown.snake", function(event) {
		if (event.keyCode == 27) self.destroy(); // escape
		else if (event.keyCode == 37) self.setDir(-1, 0); // left
		else if (event.keyCode == 38) self.setDir( 0,-1); // up
		else if (event.keyCode == 39) self.setDir( 1, 0); // right
		else if (event.keyCode == 40) self.setDir( 0, 1); // down
	});
	return self;
};
Snake.prototype.startLoop = function() {
	this.gameLoop().drawWall().draw().feedSnake();
}
Snake.prototype.gameLoop = function() {
	var self = this;
	window.clearInterval(self.interval);
	self.interval = window.setInterval(function() {
		try {
			self.setupLevel().showGameInfo();
			if (self.move(self.dir)) self.draw();
			if (self.feedFound()) self.eatFeed().feedSnake();
			self.updateHighscore();
			if (self.isCrash()) self.failed();
		} catch (e) {
			console.log(e);
			window.clearInterval(self.interval);
		}
	}, self.speed);
	return self;
};
Snake.prototype.setupLevel = function() {
	if (this.points >= this.levelup ) {
		this.level++;
		this.levelup += this.level * this.levelupFactor;
		this.speed = Math.max(this.speed - this.speedIncr, 40);
		this.gameLoop();
	}
	return this;
};
Snake.prototype.getHighscoreCookie = function() {
	var c = document.cookie;
	var regex = /snake.highscore=(\d+)/;
	var res = regex.exec(c);
	return !res  || res.length == 0 ? 0 : res[1];
};
Snake.prototype.updateHighscore = function() {
	if (this.points > this.highscore) { 
		this.highscore = this.points;
		document.cookie = "snake.highscore="+this.highscore+"; expires=Fri, 26 Feb 2027 00:00:00 UTC; path=/;";
	}
};
Snake.prototype.showGameInfo = function() {
	var self = this;
	var a = self.arena;
	var fs = self.seg;
	if (!a.pointsDiv) {
		a.pointsDiv = 
			$("<div/>")
				.css(
					{ 	position: "fixed", display: "flex", flexFlow: "row nowrap", justifyContent: "space-between",
						left: a.x+"px", top: (a.y-(1.2*fs))+"px", 
						fontSize: fs+"px", height: "1.2em", lineHeight: 1.2,
						paddingLeft: fs+"px", paddingRight: fs+"px", width: a.width-2*fs, zIndex: 10000, 
						backgroundColor: "black", color: "white", fontFamily: "monospace", fontWeight:"bold" })
				.appendTo("body")
				.append($("<div/>").html("&#8212; Snake &#8212;"))
				.append($("<div/>").append($("<span/>").html("Level: ")).append($("<span/>").addClass("level")))
				.append($("<div/>").append($("<span/>").html("Level up: ")).append($("<span/>").addClass("levelup")))
				.append($("<div/>").append($("<span/>").html("Points: ")).append($("<span/>").addClass("points")))
				.append($("<div/>").append($("<span/>").html("Highscore: ")).append($("<span/>").addClass("highscore")))
		;
	}
	//this.arena.pointsDiv.html("SNAKE -- Level: "+this.level+", Level up: "+this.levelup+", Points: "+this.points+", Highscore: "+this.highscore);
	// +", Speed: "+this.speed+", Snake length: "+(this.snake.length-1)
	function prependZeros(v,m) {
		var s = ""+v;
		while (s.length <m) s = "0"+s;
		return s;
	}
	self.arena.pointsDiv.find(".level").html(prependZeros(self.level,6));
	self.arena.pointsDiv.find(".levelup").html(prependZeros(self.levelup,6));
	self.arena.pointsDiv.find(".points").html(prependZeros(self.points,6));
	self.arena.pointsDiv.find(".highscore").html(prependZeros(self.highscore,6));
	return this;
};
Snake.prototype.addPoints = function(p) {
	this.points += p;
};
Snake.prototype.getSnakeInfo = function() {
	return { x: this.snake[0][0], y: this.snake[0][1], c: this.snake[0][2], px: this.snake[0][0] * this.seg, py: this.snake[0][1] * this.seg };
};
Snake.prototype.eatFeed = function() {
	var i = this.getSnakeInfo();
	var f = this.feed[i.x+"-"+i.y];
	this.eat.push({ s: this.level * this.segFactor, c: f.c });
	this.addPoints(this.level * this.feedFactor);
	delete this.feed[i.x+"-"+i.y];
	return this;
};
Snake.prototype.feedFound = function() {
	var x = this.snake[0][0];
	var y = this.snake[0][1];
	return this.feed[x+"-"+y];
};
Snake.prototype.feedSnake = function() {
	var x,y, r,g,b, c;
	do {
		x = Math.floor( Math.random() * this.maxX );
		y = Math.floor( Math.random() * this.maxY );
	} while ( this.isWallCrash(x,y) || this.isTailCrash(x,y));
	
	r = Math.round( Math.random() * 200 );
	g = Math.round( Math.random() * 240 );
	b = Math.round( Math.random() * 240 );
	
	c = "rgba("+r+","+g+","+b+",0.5)";
	this.feed[x+"-"+y] = { x: x, y: y, c: c };
	
	var ctx = this.arena.canvas[0].getContext("2d");
	ctx.fillStyle = c;
	ctx.fillRect(x*this.seg,y*this.seg, this.seg, this.seg);
	ctx.drawImage(this.egg, x*this.seg,y*this.seg,this.seg,this.seg);

	return this;
};
Snake.prototype.destroy = function() {
	window.clearInterval(this.interval);
	$("body").off("keydown.snake");
	this.arena.canvas.remove();
	this.arena.pointsDiv.remove();
	document.snake = false;
};
Snake.prototype.drawWall  = function() {
	var self = this;
	this.wall = {};
	for (var x=0; x<this.maxX; x++) {
		this.wall[x+"-0"] = { x: x, y: 0};
		this.wall[x+"-"+(this.maxY-1)] = { x: x, y: this.maxY-1};
	}
	for (var y=0; y<this.maxY; y++) {
		this.wall["0-"+y] = { x: 0, y: y };
		this.wall[(this.maxX-1)+"-"+y] = { x: this.maxX-1, y: y};
	}
	
	var ctx = this.arena.canvas[0].getContext("2d");
	
	ctx.fillStyle = "rgba(255,0,0,0.5)";
	Object.keys(this.wall).forEach(function(p) {
		var w = self.wall[p];
		var px = w.x * self.seg;
		var py = w.y * self.seg;
		ctx.fillRect( px, py, self.seg, self.seg);
		ctx.drawImage(self.brick, px, py, self.seg, self.seg);
	});
	return self;
};
Snake.prototype.draw = function() {
	var ctx = this.arena.canvas[0].getContext("2d");
	for (var i=this.snake.length-1; i>=0; i--) {
		var x = this.snake[i][0] * this.seg;
		var y = this.snake[i][1] * this.seg;
		var c = this.snake[i][2];
		var cs = i > 0 ? this.snake[i-1][2] : -2;
		if (c != -1) {
			if (cs != c) {
				ctx.clearRect(x, y, this.seg, this.seg);
				ctx.fillStyle = c;
				ctx.fillRect(x, y, this.seg, this.seg );
			}
		} else {
			if (this.eat.length == 0) ctx.clearRect(x, y, this.seg, this.seg);
		}
	}
	return this;
};
Snake.prototype.move = function(dir) {
	var s = this.snake;
	var l = s.length -1;
	var le = [s[l][0],s[l][1],s[l][2]]; // save last element position and colour
	for (var i=l; i>0; i--) { // set successor position
		s[i][0] = s[i-1][0];
		s[i][1] = s[i-1][1];
	}
	if (this.eat.length > 0) {
		var t = s.pop();
		s.push([t[0],t[1],this.eat[0].c]);
		s.push(le);
		this.eat[0].s--;
		if (this.eat[0].s == 0) this.eat.shift();
	}
	this.snake[0][0] += dir.x;
	this.snake[0][1] += dir.y;
	
	this.addPoints(this.level * this.stepFactor);
	
	this.steps += 1;
	
	return dir.x != 0 || dir.y != 0;
};
Snake.prototype.isWallCrash = function(x,y) {
	return this.wall[x+"-"+y];
};
Snake.prototype.isTailCrash = function(x,y) {
	var s = this.snake;
	for (var i = 1; i < s.length-1; i++) {
		if (x == s[i][0] && y == s[i][1]) return true;
	}
};
Snake.prototype.isCrash = function() {
	var s = this.snake;
	var x = s[0][0];
	var y = s[0][1];
	return this.isWallCrash(x,y) || this.isTailCrash(x,y); 
};
Snake.prototype.failed = function() {
	window.clearInterval(this.interval);
	var ctx = this.arena.canvas[0].getContext("2d");
	var fontSize = 3 * this.seg;
	var text ="FAILED!";
	ctx.font = fontSize+"px fantasy";
	if (this.points == this.highscore) {
		text = "!!! NEW HIGHSCORE !!!";
		ctx.fillStyle = "rgb(255,215,0)";
	} else {
		ctx.fillStyle = "red";
	}
	var mt = ctx.measureText(text);
	ctx.fillText(text, (this.arena.width-mt.width) / 2, (this.arena.height-fontSize)/2 );
};
Snake.prototype.setDir = function(x,y) {
	this.dir.x = x;
	this.dir.y = y;
};
$("#flt").on("fileListChanged", function() {
	$(".foldersize.filestats-foldersize").on("dblclick.snake", function() {
		document.snake ||= (new Snake()).start();
	});
});
