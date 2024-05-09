package;

import flixel.*;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.input.keyboard.FlxKeyboard;

/*
	2 tiles - a bit tricvky
	3 tiles - not bad
 */
class PlayState extends FlxState
{
	var bg:FlxSprite;

	static inline var gridwidth:Int = 10;
	static inline var gridheight:Int = 10;
	static inline var tile_w:Int = 14;
	static inline var tile_h:Int = 12;

	var px:Int = Std.int(gridwidth / 2);
	var py:Int = Std.int(gridheight / 2);
	var pstate:Int = 0; // 0 select, 1 move

	var blocks:FlxTypedGroup<FlxSprite>;
	var foundmask:Array<Bool>;
	var text_score:FlxTypedGroup<FlxSprite>;
	var text_highscore:FlxTypedGroup<FlxSprite>;
	var timer:FlxSprite;
	var cursor:FlxSprite;

	var boardstate:Array<Array<Int>>;
	var score:Int = 0;
	var highscore:Int = 0;

	public function populatestate(n:Int)
	{
		var score:Int = 0;
		boardstate = [];
		for (i in 0...gridwidth)
		{
			boardstate.push([]);
			for (j in 0...gridheight)
			{
				// there are seven block types
				boardstate[i].push(Std.random(n));
			}
		}
	}

	public function applystate()
	{
		for (i in 0...gridwidth)
		{
			for (j in 0...gridheight)
			{
				var block:FlxSprite = blocks.members[i * gridheight + j];
				if (boardstate[i][j] >= 0)
				{
					block.animation.frameIndex = boardstate[i][j];
					block.visible = true;
				}
				else
				{
					block.visible = false;
				}
			}
		}

		cursor.x = 40 + px * tile_w - tile_w; // cursor sprite has weird offset
		cursor.y = 20 + py * tile_h - tile_h;
		cursor.animation.frameIndex = pstate;
	}

	override public function create()
	{
		if (FlxG.mouse != null)
		{
			FlxG.mouse.enabled = false;
			FlxG.mouse.visible = false;
		}
		super.create();
		bg = new FlxSprite(0, 0, "assets/images/background.png");
		add(bg);

		blocks = new FlxTypedGroup<FlxSprite>();
		foundmask = [];
		for (i in 0...gridwidth)
		{
			for (j in 0...gridheight)
			{
				var block:FlxSprite = new FlxSprite();
				block.loadGraphic("assets/images/blocks.png", true, tile_w, tile_h);
				block.x = 40 + i * tile_w;
				block.y = 20 + j * tile_h;
				blocks.add(block);
				foundmask.push(true);
			}
		}
		add(blocks);

		cursor = new FlxSprite();
		cursor.loadGraphic("assets/images/selectioncursor.png", true, 24, 24);
		add(cursor);

		populatestate(7);
		applystate();
	}

	var tetromino_shapes:Array<Array<Array<Array<Int>>>> = [
		// for each color, include all rotations
		[
			// cyan, LONG
			[[1, 1, 1, 1]],
			[[1], [1], [1], [1]]
		],
		[
			// yellow, 2x2
			[[1, 1], [1, 1]]
		],
		[
			// red s
			[[1, 1, 0], [0, 1, 1]],
			[[0, 1], [1, 1], [1, 0]]
		],
		[
			// orange L
			[[0, 1], [0, 1], [1, 1]],
			[[1, 0, 0], [1, 1, 1]],
			[[1, 1], [1, 0], [1, 0]],
			[[1, 1, 1], [0, 0, 1]]
		],
		[
			// purple plus
			[[0, 1, 0], [1, 1, 1]],
			[[1, 0], [1, 1], [1, 0]],
			[[1, 1, 1], [0, 1, 0]],
			[[0, 1], [1, 1], [0, 1]]
		],
		[
			// green Z
			[[0, 1, 1], [1, 1, 0]],
			[[1, 0], [1, 1], [0, 1]]
		],
		[
			// blue J
			[[1, 0], [1, 0], [1, 1]],
			[[1, 1, 1], [1, 0, 0]],
			[[1, 1], [0, 1], [0, 1]],
			[[0, 0, 1], [1, 1, 1]]
		]
	];

	// not all silhouettes have the top left coordinate be in the tetromino - this is the x(or y?) offset the first tile on the left (top row)
	var origin_offsets = [
		// for each color, include all rotations
		[
			// cyan, LONG
			0,
			0
		],
		[
			// yellow, 2x2
			0
		],
		[
			// red s
			0,
			1
		],
		[
			// orange L
			1,
			0,
			0,
			0
		],
		[
			// purple plus
			1,
			0,
			0,
			1
		],
		[
			// green Z
			1,
			0
		],
		[
			// blue J
			0,
			0,
			0,
			2
		]
	];

	function findRegionSize(i:Int, j:Int)
	{
		// do a flood fill to find the size of the region
		var regionSize = 0;
		var stack = [];
		var visited = [];
		var colour = boardstate[i][j];
		stack.push([i, j]);
		while (stack.length > 0 && regionSize <= 50)
		{
			var pos = stack.pop();
			var x = pos[0];
			var y = pos[1];

			if (x < 0 || x >= gridwidth || y < 0 || y >= gridheight)
			{
				continue;
			}
			if (boardstate[x][y] != colour)
			{
				continue;
			}
			var skip = false;
			// if already visited, skip
			for (k in 0...visited.length)
			{
				if (visited[k][0] == x && visited[k][1] == y)
				{
					skip = true;
					break;
				}
			}
			if (skip)
			{
				continue;
			}
			regionSize++;
			visited.push([x, y]);
			stack.push([x + 1, y]);
			stack.push([x - 1, y]);
			stack.push([x, y + 1]);
			stack.push([x, y - 1]);
		}
		trace(visited);
		return regionSize;
	}

	function detectTetrominoes()
	{
		trace("detecting tetrominoes");
		// clear found mask
		for (i in 0...gridwidth)
		{
			for (j in 0...gridheight)
			{
				foundmask[i * gridheight + j] = false;
			}
		}

		// for each block type
		for (shape_i in 0...tetromino_shapes.length)
		{
			var rots = tetromino_shapes[shape_i];
			// for each rotation
			for (rot_i in 0...rots.length)
			{
				var rot = rots[rot_i];
				// for each block
				for (i in 0...(gridwidth - rot.length + 1))
				{
					for (j in 0...(gridheight - rot[0].length + 1))
					{
						var sample_position_x = i;
						var sample_position_y = j + origin_offsets[shape_i][rot_i];

						// if the block is the same as the current block type for this silhouette
						if (boardstate[sample_position_x][sample_position_y] == shape_i)
						{
							// check if the tetromino fits
							var match = true;
							for (k in 0...rot.length)
							{
								for (l in 0...rot[k].length)
								{
									if (rot[k][l] == 1)
									{
										if (i + k >= gridwidth || j + l >= gridheight || boardstate[i + k][j + l] != shape_i)
										{
											match = false;
											break;
										}
									}
								}
								if (!match)
								{
									break;
								}
							}
							if (match)
							{
								trace("found shape " + shape_i + " w/ rotation " + rot_i + " at " + i + ", " + j);
								var pointInTetromino_x = i;
								var pointInTetromino_y = j + origin_offsets[shape_i][rot_i];
								var fillarea = findRegionSize(pointInTetromino_x, pointInTetromino_y);
								trace("fillarea " + fillarea);
								if (fillarea == 4)
								{
									for (k in 0...rot.length)
									{
										for (l in 0...rot[k].length)
										{
											if (rot[k][l] == 1)
											{
												foundmask[(i + k) * gridheight + (j + l)] = true;
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}

		// remove all found tetrominoes
		for (i in 0...gridwidth)
		{
			for (j in 0...gridheight)
			{
				if (foundmask[i * gridheight + j])
				{
					boardstate[i][j] = -1;
				}
			}
		}
	}

	function pushDownPieces():Bool
	{
		// pushes down pieces, and spawns new ones on top line. returns true if any pieces were pushed down/added
		var anyPushed = false;
		for (i in 0...gridwidth)
		{
			// go from bottom to top
			for (j_bot in 1...gridheight)
			{
				var j = gridheight - j_bot - 1;
				var j_next = j + 1;
				if (boardstate[i][j] != -1 && boardstate[i][j_next] == -1)
				{
					// drop
					boardstate[i][j_next] = boardstate[i][j];
					boardstate[i][j] = -1;
				}
			}
		}
		// spawn new pieces on top line
		for (i in 0...gridwidth)
		{
			if (boardstate[i][0] == -1)
			{
				boardstate[i][0] = Std.random(7);
				anyPushed = true;
			}
		}
		return anyPushed;
	}

	function OnSwap()
	{
		detectTetrominoes();
		while (pushDownPieces()) {};
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.ONE)
		{
			populatestate(0);
			applystate();
		}
		if (FlxG.keys.justPressed.TWO)
		{
			populatestate(1);
			applystate();
		}
		if (FlxG.keys.justPressed.THREE)
		{
			populatestate(2);
			applystate();
		}
		if (FlxG.keys.justPressed.FOUR)
		{
			populatestate(3);
			applystate();
		}
		if (FlxG.keys.justPressed.FIVE)
		{
			populatestate(4);
			applystate();
		}
		if (FlxG.keys.justPressed.SIX)
		{
			populatestate(5);
			applystate();
		}
		if (FlxG.keys.justPressed.SEVEN)
		{
			populatestate(6);
			applystate();
		}
		if (FlxG.keys.justPressed.EIGHT)
		{
			populatestate(7);
			applystate();
		}

		if (FlxG.keys.justPressed.W || FlxG.keys.justPressed.UP)
		{
			if (py > 0)
			{
				if (pstate == 0)
				{
					py--;
				}
				else
				{
					// swap with tile and tile above
					var temp:Int = boardstate[px][py];
					boardstate[px][py] = boardstate[px][py - 1];
					boardstate[px][py - 1] = temp;
					pstate = 0;
					py--;
					OnSwap();
				}
			}
		}
		if (FlxG.keys.justPressed.S || FlxG.keys.justPressed.DOWN)
		{
			if (py < gridheight - 1)
			{
				if (pstate == 0)
				{
					py++;
				}
				else
				{
					// swap with tile and tile below
					var temp:Int = boardstate[px][py];
					boardstate[px][py] = boardstate[px][py + 1];
					boardstate[px][py + 1] = temp;
					pstate = 0;
					py++;
					OnSwap();
				}
			}
		}
		if (FlxG.keys.justPressed.A || FlxG.keys.justPressed.LEFT)
		{
			if (px > 0)
			{
				if (pstate == 0)
				{
					px--;
				}
				else
				{
					// swap with tile and tile to the left
					var temp:Int = boardstate[px][py];
					boardstate[px][py] = boardstate[px - 1][py];
					boardstate[px - 1][py] = temp;
					pstate = 0;
					px--;
					OnSwap();
				}
			}
		}
		if (FlxG.keys.justPressed.D || FlxG.keys.justPressed.RIGHT)
		{
			if (px < gridwidth - 1)
			{
				if (pstate == 0)
				{
					px++;
				}
				else
				{
					// swap with tile and tile to the right
					var temp:Int = boardstate[px][py];
					boardstate[px][py] = boardstate[px + 1][py];
					boardstate[px + 1][py] = temp;
					pstate = 0;
					px++;
					OnSwap();
				}
			}
		}
		if (FlxG.keys.justPressed.SPACE || FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.X || FlxG.keys.justPressed.C)
		{
			pstate = 1 - pstate;
		}
		applystate();
	}
}
