package arm;

import iron.system.Input;
import iron.object.Transform;
import iron.object.CameraObject;
import iron.Trait;
import iron.Scene;

class StepCamera extends Trait {

	var camera:CameraObject;
	var transform:Transform;

	var maze:MazeGenerator;

	public var posX:Int;
	public var posY:Int;
	var dir:Int;

	var rotCurrent = 0.0;
	var posCurrent = 0.0;
	var strafeCurrent = 0.0;
	var liftCurrent = 0.0;
	var rotLast = 0.0;
	var posLast = 0.0;
	var strafeLast = 0.0;
	var liftLast = 0.0;
	var moveComplete = true;

	var moveForward = false;
	var moveBackward = false;
	var strafeLeft = false;
	var strafeRight = false;
	var turnLeft = false;
	var turnRight = false;

	public static var inst:StepCamera = null;

	public function new() {
		super();

		inst = this;

		notifyOnInit(init);
		notifyOnUpdate(update);
	}

	function init() {
		transform = object.transform;
		camera = cast object;

		maze = MazeGenerator.inst;
		posX = maze.floor.startX;
		posY = maze.floor.startY;
		dir = maze.floor.startDir;

		// Set camera position
		transform.loc.x = maze.getWorldX(posX);
		transform.loc.y = maze.getWorldY(posY);
		if (dir != 0) camera.rotate(iron.math.Vec4.zAxis(), -dir * (3.1415 / 2));
		transform.dirty = true;
		transform.update();
	}

	var startX:Float = 0;
	var startY:Float = 0;
	function update() {
		var kb = iron.system.Input.getKeyboard();
		if (kb.started("up") || kb.started("w")) moveForward = true;
		else if (kb.started("down") || kb.started("s")) moveBackward = true;
		else if (kb.started("left") || kb.started("a")) turnLeft = true;
		else if (kb.started("right") || kb.started("d")) turnRight = true;
		else if (kb.started("q")) strafeLeft = true;
		else if (kb.started("e")) strafeRight = true;
		if (kb.released("up") || kb.released("w")) moveForward = false;
		else if (kb.released("down") || kb.released("s")) moveBackward = false;
		else if (kb.released("left") || kb.released("a")) turnLeft = false;
		else if (kb.released("right") || kb.released("d")) turnRight = false;
		else if (kb.released("q")) strafeLeft = false;
		else if (kb.released("e")) strafeRight = false;

		#if (kha_ios || kha_android)
		var surf = iron.system.Input.getSurface();
		moveForward = false;
		moveBackward = false;
		turnLeft = false;
		turnRight = false;
		if (surf.started()) {
			startX = surf.x;
			startY = surf.y;
		}
		else if (surf.released()) {
			var dx = surf.x - startX;
			var dy = surf.y - startY;

			if (Math.abs(dx) > Math.abs(dy)) {
				if (dx > 0) turnRight = true;
				else turnLeft = true;
			}
			else {
				if (dy <= 0) moveForward = true;
				else moveBackward = true;
			}
		}
		#end

		var rotDif = rotCurrent - rotLast;
		var posDif = posCurrent - posLast;
		var strafeDif = strafeCurrent - strafeLast;
		var liftDif = liftCurrent - liftLast;
		rotLast = rotCurrent;
		posLast = posCurrent;
		strafeLast = strafeCurrent;
		liftLast = liftCurrent;

		if (rotDif != 0) camera.rotate(iron.math.Vec4.zAxis(), rotDif);
		if (posDif != 0) camera.move(camera.look(), posDif);
		if (strafeDif != 0) {
			if (dir == 1 || dir == 3) camera.move(camera.right(), strafeDif);
			else camera.move(camera.right(), -strafeDif);
		}
		if (liftDif != 0) {
			camera.move(camera.up(), liftDif);
		}

		// Controls
		if (moveForward) move(1);
		else if (moveBackward) move(-1);
		else if (strafeLeft) {
			if (dir == 1 || dir == 3) { strafe(-1); }
			else { strafe(1); }
		}
		else if (strafeRight) {
			if (dir == 1 || dir == 3) { strafe(1); }
			else { strafe(-1); }
		}

		if (turnLeft) turn(1);
		else if (turnRight) turn(-1);
	}

	function move(dist:Int) {
		if (!moveComplete) return;

		var targetX = posX;
		var targetY = posY;

		if (dir == 1) targetX += dist;
		else if (dir == 2) targetY -= dist;
		else if (dir == 3) targetX -= dist;
		else targetY += dist;

		moveTo(targetX, targetY, dist, "move");
	}

	function strafe(dist:Int) {
		if (!moveComplete) return;

		var targetX = posX;
		var targetY = posY;

		if (dir == 1) targetY -= dist;
		else if (dir == 2) targetX += dist;
		else if (dir == 3) targetY += dist;
		else targetX -= dist;

		moveTo(targetX, targetY, dist, "strafe");
	}

	function delayMove(t = 0.2) { // Prevents from moving for certain time
		moveComplete = false;
		iron.system.Tween.timer(t, moved);
	}

	function moved() {
		moveComplete = true;
		maze.moveThings();
	}

	function moveTo(targetX:Int, targetY:Int, dist:Int, type:String) {
		if (maze.gameOver) return;

		// Check for things
		var things = maze.floor.things;
		for (t in things) {
			// Thing found
			if (t.x == targetX && t.y == targetY) {
				// Lever
				if (t.type == MazeGenerator.THING_LEVER) {
					// Set state of target
					var tt = maze.getThingById(t.targetId);
					if (tt != null && tt.type == MazeGenerator.THING_GATE) {
						maze.leverAction(t);
						maze.gateAction(tt);
						delayMove();
					}
					return;
				}
				// God mode can move everywhere
				else if (!MazeGenerator.godMode) {
					// Gate
					if (t.type == MazeGenerator.THING_GATE) {
						// Gate closed
						if (t.state == 0) return;
					}
					// Hammer
					else if (t.type == MazeGenerator.THING_HAMMER) {
						// Hammer down
						if (t.state == 0) return;
					}
					// Mover
					else if (t.type == MazeGenerator.THING_MOVER) {
						return;
					}
				}
			}
		}

		// Move
		if ((!maze.isWall(targetX, targetY) || MazeGenerator.godMode) && !maze.isStairsDown(targetX, targetY)) {

			// iron.data.Data.getSound("step", function(s:kha.Sound) { iron.system.Audio.play(s); });

			moveComplete = false;
			if (type == "move") {
				posCurrent = 0;
				posLast = 0;
			}
			else if (type == "strafe") {
				strafeCurrent = 0;
				strafeLast = 0;
			}

			var isStairs = maze.isStairs(targetX, targetY);
			//var isStairsDown = maze.isStairsDown(targetX, targetY);
			var moveTime = isStairs ? 1.0 : 0.2;

			posX = targetX;
			posY = targetY;

			if (type == "move") {
				iron.system.Tween.to({
					target: this,
					duration: moveTime,
					props: { posCurrent: MazeGenerator.tileSize * dist },
					done: moved
				});
			}
			else if (type == "strafe") {
				iron.system.Tween.to({
					target: this,
					duration: moveTime,
					props: { strafeCurrent:MazeGenerator.tileSize * dist },
					done: moved
				});
			}

			// Level completed
			if (isStairs) {
				// Next floor
				MazeGenerator.nextFloor();

				// Camera up
				iron.system.Tween.to({
					target: this,
					duration: moveTime,
					props: { liftCurrent: MazeGenerator.tileSize * dist }
				});

				// Reset and load next floor
				maze.reset();
			}
			/*else if (isStairsDown) {
				MazeGenerator.previousFloor();
				// Camera down
				iron.system.Tween.to({
					target: this,
					duration: moveTime,
					props: { liftCurrent: -MazeGenerator.tileSize * dist }
				});
				maze.reset();
			}*/
		}
	}

	function turn(sign:Int) {
		if (!moveComplete) return;

		moveComplete = false;
		rotCurrent = 0;
		rotLast = 0;

		dir -= sign;
		if (dir < 0) dir = 3;
		else if (dir > 3) dir = 0;
		var f = sign * (3.1415 / 2);

		iron.system.Tween.to({
			target: this,
			duration: 0.2,
			props: { rotCurrent: f },
			done: function() { moveComplete = true; }
		});
	}
}
