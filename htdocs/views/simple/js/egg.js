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
	this.eat = [ ]; // array of { s: segments, c: color }
	this.snake = [ [4,1,"rgba(0,0,255,0.5)"], [3,1,"rgba(0,255,0,0.5)"], [2,1,"rgba(255,255,0,0.5)"], [1,1,-1] ];
	this.dir = { x: 1, y: 0 };
	this.wall = {};
	this.feed = {};
	this.elements = 60; // elements in a row 
	this.highscore = this.getHighscoreCookie();
	
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
	console.log(this);
}
Snake.prototype.start = function() {
	console.log("Start snake.");
	var self = this;
	self.arena.canvas = $("<canvas/>")
		.attr({tabindex : 0, width: self.arena.width, height: self.arena.height })
		.css({position: "fixed", left: self.arena.x + "px", top: self.arena.y + "px", zIndex: 10000})
		.appendTo("body")
		.focus();
	$("body").on("keydown.snake", function(event) {
		if (event.keyCode == 27) self.destroy(); // escape
		else if (event.keyCode == 37) self.setDir(-1, 0); // left
		else if (event.keyCode == 38) self.setDir( 0,-1); // up
		else if (event.keyCode == 39) self.setDir( 1, 0); // right
		else if (event.keyCode == 40) self.setDir( 0, 1); // down
	});
	
	self.gameLoop();
	self.drawWall();
	self.draw();
	self.feedSnake();
}
Snake.prototype.gameLoop = function() {
	var self = this;
	window.clearInterval(self.interval);
	self.interval = window.setInterval(function() {
		try {
			self.setupLevel();
			self.showGameInfo();
			if (self.move(self.dir)) self.draw();
			if (self.feedFound()) {
				self.eatFeed();
				self.feedSnake();
			}
			self.updateHighscore();
			if (self.isCrash()) self.failed();
		} catch (e) {
			console.log(e);
			window.clearInterval(self.interval);
		}
	}, self.speed);
}
Snake.prototype.setupLevel = function() {
	if (this.points >= this.levelup ) {
		this.level++;
		this.levelup += this.level * this.levelupFactor;
		this.speed = Math.max(this.speed - this.speedIncr, 40);
		this.gameLoop();
	}
}
Snake.prototype.getHighscoreCookie = function() {
	var c = document.cookie;
	var regex = /snake.highscore=(\d+)/;
	var res = regex.exec(c);
	return res == null  || res.length == 0 ? 0 : res[1];
}
Snake.prototype.updateHighscore = function() {
	if (this.points > this.highscore) { 
		this.highscore = this.points;
		document.cookie = "snake.highscore="+this.highscore+"; expires=Fri, 26 Feb 2027 00:00:00 UTC; path=/;";
	}
}
Snake.prototype.showGameInfo = function() {
	if (!this.arena.pointsDiv) {
		this.arena.pointsDiv = $("<div/>").css({ position: "fixed", left: this.arena.x+"px", top: (this.arena.y-(2*this.seg))+"px", fontSize: this.seg+"px", zIndex: 10000, background: "white" }).appendTo("body");
	}
	this.arena.pointsDiv.html("SNAKE -- Level: "+this.level+", Level up: "+this.levelup+", Points: "+this.points+", Highscore: "+this.highscore);
	// +", Speed: "+this.speed+", Snake length: "+(this.snake.length-1)
}
Snake.prototype.addPoints = function(p) {
	this.points += p;
}
Snake.prototype.getSnakeInfo = function() {
	return { x: this.snake[0][0], y: this.snake[0][1], c: this.snake[0][2] };
}
Snake.prototype.eatFeed = function() {
	var i = this.getSnakeInfo();
	var f = this.feed[i.x+"-"+i.y];
	this.eat.push({ s: this.level * this.segFactor, c: f.c });
	this.addPoints(this.level * this.feedFactor);
	delete this.feed[i.x+"-"+i.y];
}
Snake.prototype.feedFound = function() {
	var x = this.snake[0][0];
	var y = this.snake[0][1];
	return this.feed[x+"-"+y];
}
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
}
Snake.prototype.destroy = function() {
	console.log("Destroy snake");
	window.clearInterval(this.interval);
	$("body").off("keydown.snake");
	this.arena.canvas.remove();
	this.arena.pointsDiv.remove();
	console.log(this.snake);
}
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
		ctx.fillRect( w.x * self.seg, w.y * self.seg, self.seg, self.seg);
	});
}
Snake.prototype.draw = function() {
	var ctx = this.arena.canvas[0].getContext("2d");
	for (var i=0; i<this.snake.length; i++) {
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
			ctx.clearRect(x, y, this.seg, this.seg);
		}
	}
}
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
	
	return dir.x != 0 || dir.y != 0;
}
Snake.prototype.isWallCrash = function(x,y) {
	return this.wall[x+"-"+y];
}
Snake.prototype.isTailCrash = function(x,y) {
	var s = this.snake;
	for (var i = 1; i < s.length-1; i++) {
		if (x == s[i][0] && y == s[i][1]) return true;
	}
}
Snake.prototype.isCrash = function() {
	var s = this.snake;
	var x = s[0][0];
	var y = s[0][1];
	return this.isWallCrash(x,y) || this.isTailCrash(x,y); 
}
Snake.prototype.failed = function() {
	console.log("Snake failed");
	window.clearInterval(this.interval);
	var ctx = this.arena.canvas[0].getContext("2d");
	
}
Snake.prototype.setDir = function(x,y) {
	this.dir.x = x;
	this.dir.y = y;
};
$("#flt").on("fileListChanged", function() {
	$(".foldersize.filestats-foldersize").on("dblclick.snake", function() {
		$(this).off("dblclick.snake");
		var snake = new Snake();
		snake.start();
	});
});
