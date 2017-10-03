package arm;

import iron.Trait;
import iron.Scene;
import iron.object.Object;
import iron.data.SceneFormat;
import arm.FloorsData;

class MazeGenerator extends Trait {

	static var currentFloor = 0;

	public static inline var tileSize = 2;

	public static inline var TILE_EMPTY = 0;
	public static inline var TILE_WALL = 1;
	public static inline var TILE_STAIRS = 2;
	public static inline var TILE_STAIRS_DOWN = 3;

	public static inline var THING_LEVER = 0;
	public static inline var THING_GATE = 1;
	public static inline var THING_HAMMER = 2;
	public static inline var THING_SPIKE = 3;
	public static inline var THING_MOVER = 4;
	public static inline var THING_GUN = 5;

	var cam:StepCamera;

	public var floor:Floor;
	var maze:Array<Array<Int>>;
	var mazeDirs:Array<Array<Int>>;
	var mazeWidth:Int; 
	var mazeHeight:Int;
	var things:Array<Thing>;

	static var first = true;
	public static var inst:MazeGenerator = null;

	public var gameOver = false;

	static var editorFloor:Floor = null;
	public static var godMode = false;

	public function new() {
		super();

		inst = this;

		if (editorFloor == null) {
			floor = FloorsData.getFloor(currentFloor);
			godMode = false;
		}
		else {
			floor = editorFloor;
			godMode = true;
		}
		maze = floor.data;
		mazeDirs = floor.dirs;
		mazeWidth =  maze[0].length;
		mazeHeight = maze.length;
		things = floor.things;

		notifyOnInit(init);

		if (first) {
			first = false;
			// iron.system.Audio.play("music", true);
		}
	}

	function init() {
		cam = StepCamera.inst;
		var scene = iron.Scene.active;

		var nodes = ["Floor", "Cube", "Stairs", "StairsDown"];
		var ceilNodes = ["Ceil"];
		var thingNodes = ["Lever", "Gate", "Hammer", "Spike", "Mover", "Gun"];

		// Tiles
		for (i in 0...mazeHeight) {
			for (j in 0...mazeWidth) {
				var m = maze[i][j];
				placeNode(nodes[m], i, j);
				// Ceiling
				if (m == TILE_EMPTY || m == TILE_STAIRS_DOWN) {
					placeNode(ceilNodes[0], i, j, true);
				}
			}
		}

		// Things
		for (t in things) {
			scene.spawnObject(thingNodes[t.type], null, function(o) {
				o.transform.loc.x = getWorldX(t.x);
				o.transform.loc.y = getWorldY(t.y);

				if (t.dir != 0) o.transform.rotate(iron.math.Vec4.zAxis(), t.dir * (3.1415 / 2));
				t.object = o;
				o.transform.dirty = true;
				initThing(t);
			});
		}
	}

	function placeNode(node:String, i:Int, j:Int, ceiling = false) {
		var scene = iron.Scene.active;
		scene.spawnObject(node, null, function(o) {
			o.transform.loc.x = getWorldX(j);
			o.transform.loc.y = getWorldY(i);
			var md = mazeDirs[i][j];
			if (md != 0) o.transform.rotate(iron.math.Vec4.zAxis(), md * (3.1415 / 2));
			o.transform.dirty = true;
		});
	}

	public function isWall(x:Int, y:Int) {
		if (x < 0 || x > mazeWidth - 1 || y < 0 || y > mazeHeight - 1) return true;
		return maze[y][x] == TILE_WALL ? true : false;
	}

	public function isStairs(x:Int, y:Int) {
		if (x < 0 || x > mazeWidth - 1 || y < 0 || y > mazeHeight - 1) return false;
		return maze[y][x] == TILE_STAIRS ? true : false;
	}

	public function isStairsDown(x:Int, y:Int) {
		if (x < 0 || x > mazeWidth - 1 || y < 0 || y > mazeHeight - 1) return false;
		return maze[y][x] == TILE_STAIRS_DOWN ? true : false;
	}

	public function getWorldX(x:Int) {
		return x * tileSize - (mazeWidth - 1) * tileSize / 2;
	}

	public function getWorldY(y:Int) {
		return y * tileSize - (mazeHeight - 1) * tileSize / 2;
	}

	public static function nextFloor() {
		currentFloor++;
	}

	public static function previousFloor() {
		currentFloor--;
	}

	public static function setFloor(i:Int) {
		currentFloor = i;
	}

	public function getThingById(id:Int):Thing {
		for (t in things) {
			if (t.id == id) return t;
		}
		return null;
	}

	public function leverAction(t:Thing) {
		// iron.data.Data.getSound("lever", function(s:kha.Sound) { iron.system.Audio.play(s); });

		// Open
		if (t.state == 0) {
			t.state = 1;
			iron.system.Tween.to({
				target: t.object.transform.loc,
				duration: 0.2,
				props: { z: -0.5 },
				tick: function() { t.object.transform.dirty = true; }
			});
		}
		// Close
		else {
			t.state = 0;
			iron.system.Tween.to({
				target: t.object.transform.loc,
				duration: 0.2,
				props: { z: 0.0 },
				tick: function() { t.object.transform.dirty = true; }
			});
		}
	}

	public function gateAction(t:Thing) {
		// Open
		if (t.state == 0) {
			t.state = 1;
			iron.system.Tween.to({
				target: t.object.transform.loc,
				duration: 0.2,
				props: { z: 1.8 },
				tick: function() { t.object.transform.dirty = true; }
			});
		}
		// Close
		else {
			t.state = 0;
			iron.system.Tween.to({
				target: t.object.transform.loc,
				duration: 0.2,
				props: { z: 0.0 },
				tick: function() { t.object.transform.dirty = true; }
			});
		}
	}

	public function moveThings() {
		for (t in things) {
			// Hammers
			if (t.type == THING_HAMMER) {
				t.i++;
				if (t.i >= t.rate) {
					t.i = 0;
					// Move up
					if (t.state == 0) {
						t.state = 1;
						iron.system.Tween.to({
							target: t.object.transform.loc,
							duration: 0.2,
							props: { z: 1.8 },
							tick: function() { t.object.transform.dirty = true; }
						});
					}
					// Move down
					else {
						t.state = 0;
						iron.system.Tween.to({
							target: t.object.transform.loc,
							duration: 0.2,
							props: { z: 0.0 },
							tick: function() { t.object.transform.dirty = true; }
						});
						// Check player
						if (t.x == cam.posX && t.y == cam.posY) {
							die();
						}
					}
				}
			}
			// Spikes
			else if (t.type == THING_SPIKE) {
				t.i++;
				if (t.i >= t.rate) {
					t.i = 0;
					// Hit
					var originZ = t.object.transform.loc.z;
					
					iron.system.Tween.to({
						target: t.object.transform.loc,
						duration: 0.1,
						props: { z: 0.0 },
						tick: function() { t.object.transform.dirty = true; },
						done: function() {

							iron.system.Tween.to({
								target: t.object.transform.loc,
								duration: 0.1,
								props: { z: originZ },
								tick: function() { t.object.transform.dirty = true; }
							});
						}
					});

					// Check player
					if (t.x == cam.posX && t.y == cam.posY) {
						die();
					}
				}
			}
			// Movers
			else if (t.type == THING_MOVER) {
				// Set state when wall is hit
				if (t.state == 0 && isWall(t.x + 1, t.y)) { t.state = 1; }
				else if (t.state == 1 && isWall(t.x - 1, t.y)) { t.state = 0; }
				// Move
				if (t.state == 0) { t.x++; }
				else if (t.state == 1) { t.x--; }

				iron.system.Tween.to({
					target: t.object.transform.loc,
					duration: 0.2,
					props: { x: getWorldX(t.x) },
					tick: function() { t.object.transform.dirty = true; }
				});

				// Check player
				if (t.x == cam.posX && t.y == cam.posY) {
					die();
				}
			}
			// Guns
			else if (t.type == THING_GUN) {
				t.i++;
				if (t.i >= t.rate) {
					t.i = 0;
					// Move
					if (t.x == 0) t.x = mazeWidth - 1;
					else t.x = 0;
					
					iron.system.Tween.to({
						target: t.object.transform.loc,
						duration: 0.2,
						props: { x: getWorldX(t.x) },
						tick: function() { t.object.transform.dirty = true; }
					});

					// Check player
					if (t.y == cam.posY) {
						die();
					}
				}
			}
		}
	}

	function initThing(t:Thing) {
		if (t.type == THING_GATE || t.type == THING_HAMMER) {
			if (t.state == 1) {
				t.object.transform.loc.z = 1.8;
				t.object.transform.dirty = true;
			}
		}
		else if (t.type == THING_SPIKE) {
			t.object.transform.loc.z = -0.8;
			t.object.transform.dirty = true;
		}
	}

	function die() {
		if (godMode) return;

		// iron.data.Data.getSound("die", function(s:kha.Sound) { iron.system.Audio.play(s); });
		reset();
	}

	public function reset(floor:Floor = null) {
		editorFloor = floor;
		gameOver = true;
		iron.Scene.setActive("Scene");
	}
}
