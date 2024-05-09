package;

import flixel.*;
import flixel.FlxBasic.FlxType;
import flixel.effects.particles.FlxEmitter;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.input.keyboard.FlxKeyboard;
import flixel.util.FlxSave;

/*
	sfx needed
	start game S
	lose D
	drop piece D
	match D
	win
 */
class PlayState extends FlxState
{
	var bg:FlxSprite;
	var gameover:Bool = false;

	static inline var tile_w:Int = 14;
	static inline var tile_h:Int = 12;

	static inline var playarea_x:Int = 28;
	static inline var playarea_y:Int = -1 * tile_h;
	static inline var gridwidth:Int = 10;
	static inline var gridheight:Int = 21;

	static inline var nextblock_x:Int = 196;
	static inline var nextblock_y:Int = 180;

	var gotten_forms:Array<Bool> = [false, false, false, false, false, false, false];

	var nextblock_shape:Int = 0;
	var nextblock_colours = [0, 0, 0, 0];

	var px:Int = Std.int(gridwidth / 2);
	var py:Int = Std.int(gridheight / 2);
	var p_shape:Int = -1;
	var p_colours = [0, 0, 0, 0];
	var p_rot:Int = 0;

	var blocks:FlxTypedGroup<FlxSprite>;
	var foundmask:Array<Bool>;
	var sprites_matches:FlxTypedGroup<FlxSprite>;

	var timer:FlxSprite;

	var fallingblock:FlxSpriteGroup;
	var nextblock_spr:FlxSpriteGroup;

	var particles:FlxEmitter;

	var boardstate:Array<Array<Int>>;

	var dropInterval:Float = 2;
	var dropPhase:Float = 0;
	var leftPhase:Float = 0;
	var rightPhase:Float = 0;

	public function canFit(x, y, rot)
	{
		var block = tetromino_shapes[p_shape][rot];
		for (i in 0...block.length)
		{
			for (j in 0...block[i].length)
			{
				if (block[i][j] > 0)
				{
					if (x + i < 0 || x + i >= gridwidth || y + j < 0 || y + j >= gridheight)
					{
						return false;
					}
					if (boardstate[x + i][y + j] >= 0)
					{
						return false;
					}
				}
			}
		}
		return true;
	}

	var wallKick_JLTSZ_clockwise = [
		// sourcerot: 0
		[[0, 0], [-1, 0], [-1, 1], [0, -2], [-1, -2]],
		// sourcerot: 1
		[[0, 0], [1, 0], [1, -1], [0, 2], [1, 2]],
		// sourcerot: 2
		[[0, 0], [1, 0], [1, 1], [0, -2], [1, -2]],
		// sourcerot: 3
		[[0, 0], [-1, 0], [-1, -1], [0, 2], [-1, 2]]
	];

	var wallKick_I_clockwise = [
		// sourcerot: 0
		[[0, 0], [-2, 0], [1, 0], [-2, -1], [1, 2]],
		// sourcerot: 1
		[[0, 0], [-1, 0], [2, 0], [-1, 2], [2, -1]],
		// sourcerot: 2
		[[0, 0], [2, 0], [-1, 0], [2, 1], [-1, -2]],
		// sourcerot: 3
		[[0, 0], [1, 0], [-2, 0], [1, -2], [-2, 1]]
	];

	public function moveBlock(dx:Int, dy:Int, dr:Int)
	{
		//-1 is clockwise, +1 is counterclockwise

		var moved = false;

		if (dr == 0)
		{
			if (canFit(px + dx, py + dy, (p_rot + dr + 4) % 4))
			{
				px += dx;
				py += dy;
				p_rot = (p_rot + dr + 4) % 4;
				moved = true;
			}
		}
		else
		{
			// https://tetris.fandom.com/wiki/SRS#Basic_Rotation
			var converted_rot = (4 - p_rot) % 4;
			var kicksign = dr > 0 ? -1 : 1;
			var target_rot = (p_rot + dr + 4) % 4;
			// if counter-clockwise, 3 to 2, say, treat it as 2 to 3 with negated kicks
			if (dr > 0)
			{
				// dr is positive, so in the converted space, it's negative, so we subract
				converted_rot = (converted_rot - 1 + 4) % 4;
			}
			var kicksequence = p_shape == 0 ? wallKick_I_clockwise[converted_rot] : wallKick_JLTSZ_clockwise[converted_rot];

			trace("rotating block " + p_rot + " delta " + dr);
			trace("converted rot " + converted_rot);

			for (i in 0...kicksequence.length)
			{
				var kick = kicksequence[i];
				var target_x = px + dx + kick[0] * kicksign;
				var target_y = py + dy + kick[1] * kicksign;
				trace("trying kick " + kick[0] + ", " + kick[1]);
				if (canFit(target_x, target_y, target_rot))
				{
					trace("succeeded");
					px = target_x;
					py = target_y;
					p_rot = target_rot;
					moved = true;
					break;
				}
			}
		}

		if (!moved && dy > 0)
		{
			placeBlock();
		}

		applystate();
	}

	public function chooseNext()
	{
		nextblock_shape = Std.random(7);
		for (i in 0...4)
		{
			nextblock_colours[i] = Std.random(7);
		}
	}

	function placeBlock()
	{
		FlxG.sound.play(AssetPaths.drop__mp3);

		if (p_shape >= 0)
		{
			// step one, copy the block into the boardstate
			var block = tetromino_shapes[p_shape][p_rot];

			for (i in 0...block.length)
			{
				for (j in 0...block[i].length)
				{
					if (block[i][j] > 0)
					{
						boardstate[px + i][py + j] = p_colours[block[i][j] - 1];

						// add particles
					}
				}
			}
			detectTetrominoes();
		}

		// reset position and choose block tpye
		px = Std.int(gridwidth / 2) - 2;
		py = 0;
		p_shape = nextblock_shape;
		for (i in 0...4)
		{
			p_colours[i] = nextblock_colours[i];
		}
		p_rot = 0;
		if (!canFit(px, py, p_rot))
		{
			// reset game
			var lostText = new FlxSprite(0, 0, "assets/images/youlose.png");
			add(lostText);
			// center in screen
			lostText.x = (FlxG.width - lostText.width) / 2;
			lostText.y = (FlxG.height - lostText.height) / 2;
			FlxG.sound.play(AssetPaths.lose__mp3);
			gameover = true;
			return;
		}
		chooseNext();

		// while (pushDownPieces())
		// {
		// 	detectTetrominoes();
		// }
	}

	public function checkGameOver(forcewin:Bool = false)
	{
		var haswon:Bool = gotten_forms[0] && gotten_forms[1] && gotten_forms[2] && gotten_forms[3] && gotten_forms[4] && gotten_forms[5] && gotten_forms[6];
		if (haswon || forcewin)
		{
			trace("YOU WIN");
			var winText = new FlxSprite(0, 0, "assets/images/wonmessage.png");
			add(winText);

			FlxG.sound.playMusic("assets/music/endtrack.mp3", 1.0, true);
			Menu.playingendmusic = true;

			gameover = true;
		}
	}

	public function populatestate()
	{
		var score:Int = 0;
		boardstate = [];
		for (i in 0...gridwidth)
		{
			boardstate.push([]);
			for (j in 0...gridheight)
			{
				// there are seven block types
				// boardstate[i].push(Std.random(n));
				boardstate[i].push(-1);
			}
		}

		chooseNext();
	}

	public function setNumberLabelText(num:Int, text:FlxTypedGroup<FlxSprite>)
	{
		var num_str = Std.string(num);
		while (num_str.length < 7)
		{
			num_str = "0" + num_str;
		}
		for (i in 0...num_str.length)
		{
			var digit = num_str.charCodeAt(i) - "0".charCodeAt(0);
			text.members[i].animation.frameIndex = digit;
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

		// set falling block + contents
		fallingblock.x = playarea_x + px * tile_w;
		fallingblock.y = playarea_y + py * tile_h;
		for (i in 0...4)
		{
			for (j in 0...4)
			{
				var block:FlxSprite = fallingblock.members[i * 4 + j];
				var blocktype = tetromino_shapes[p_shape][p_rot][i][j];
				if (blocktype > 0)
				{
					var colour = p_colours[blocktype - 1];
					block.animation.frameIndex = colour;
					block.visible = true;
				}
				else
				{
					block.visible = false;
				}
			}
		}

		// set next block
		for (i in 0...4)
		{
			for (j in 0...4)
			{
				var block:FlxSprite = nextblock_spr.members[i * 4 + j];
				var blocktype = tetromino_shapes[nextblock_shape][0][i][j];
				if (blocktype > 0)
				{
					var colour = nextblock_colours[blocktype - 1];
					block.animation.frameIndex = colour;
					block.visible = true;
				}
				else
				{
					block.visible = false;
				}
			}
		}
		nextblock_spr.x = nextblock_x + next_display_offset_x[nextblock_shape];
		nextblock_spr.y = nextblock_y + next_display_offset_y[nextblock_shape];

		for (i in 0...7)
		{
			sprites_matches.members[i].visible = gotten_forms[i];
		}
	}

	override public function create()
	{
		if (FlxG.sound.music == null || FlxG.sound.music.playing == false || Menu.playingendmusic)
		{
			FlxG.sound.playMusic(AssetPaths.music__mp3, 0.5, true);
			Menu.playingendmusic = false;
		}

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
				block.loadGraphic("assets/images/blocks.png", true, tile_w + 1, tile_h);
				block.x = playarea_x + i * tile_w;
				block.y = playarea_y + j * tile_h;
				blocks.add(block);
				foundmask.push(true);
			}
		}
		add(blocks);

		fallingblock = new FlxSpriteGroup(0, 0, 16);
		for (i in 0...4)
		{
			for (j in 0...4)
			{
				var spr:FlxSprite = new FlxSprite();
				spr.loadGraphic("assets/images/blocks.png", true, tile_w + 1, tile_h);
				spr.x = i * tile_w;
				spr.y = j * tile_h;
				spr.visible = false;
				fallingblock.add(spr);
			}
		}
		add(fallingblock);

		nextblock_spr = new FlxSpriteGroup(0, 0, 16);
		for (i in 0...4)
		{
			for (j in 0...4)
			{
				var spr:FlxSprite = new FlxSprite();
				spr.loadGraphic("assets/images/blocks.png", true, tile_w + 1, tile_h);
				spr.x = i * tile_w;
				spr.y = j * tile_h;
				nextblock_spr.add(spr);
			}
		}
		add(nextblock_spr);

		sprites_matches = new FlxTypedGroup<FlxSprite>();
		var coords = [
			// long,square,s,l,+,z,j

			// s and z ned to be swapped
			[189, 12], // long
			[189, 60], // sqiare
			[189, 30], // z
			[210, 78], // l
			[224, 36], // +
			[210, 126], // s
			[189, 96] // j
		];

		for (i in 0...7)
		{
			var spr:FlxSprite = new FlxSprite(coords[i][0], coords[i][1], "assets/images/uib_" + i + ".png");
			sprites_matches.add(spr);
		}
		add(sprites_matches);

		particles = new FlxEmitter(0, 0, 100);
		particles.launchAngle.set(0, -360);
		particles.angle.set(0, 360);
		particles.speed.set(0, 10);
		particles.solid = true;
		particles.angularVelocity.set(-360, 360);
		particles.acceleration.set(-0.1, -0.1, 0.1, 0.1);
		particles.elasticity.set(0.5);
		particles.lifespan.set(3, 5);
		particles.scale.set(0.5, 0.5, 0.5, 0.5, 3, 3, 3, 3);
		particles.autoUpdateHitbox = true;
		particles.alpha.set(0.5, 0.5, 0.1, 0.1);
		particles.loadParticles("assets/images/particle.png", 100, true);
		add(particles);
		particles.start(false, 1, 0);
		particles.emitting = false;

		populatestate();
		chooseNext();
		placeBlock();
		applystate();
	}

	var next_display_offset_x:Array<Int> = [
		// long,square,s,l,+,z,j
		0,
		0,
		Std.int(tile_w / 2),
		Std.int(tile_w / 2),
		Std.int(tile_w / 2),
		Std.int(tile_w / 2),
		Std.int(tile_w / 2),
	];
	var next_display_offset_y:Array<Int> = [
		// long,square,s,l,+,z,j
		//
		Std.int(tile_h / 2),
		-0,
		-0,
		-0,
		0,
		0,
		0,
	];

	var tetromino_shapes:Array<Array<Array<Array<Int>>>> = [
		// for each color, include all rotations
		[
			// cyan, LONG
			[
				//
				[0, 4, 0, 0],
				[0, 3, 0, 0],
				[0, 2, 0, 0],
				[0, 1, 0, 0]
			],
			[
				//
				[0, 0, 0, 0],
				[1, 2, 3, 4],
				[0, 0, 0, 0],
				[0, 0, 0, 0]
			],
			[
				//
				[0, 0, 1, 0],
				[0, 0, 2, 0],
				[0, 0, 3, 0],
				[0, 0, 4, 0]
			],
			[
				//
				[0, 0, 0, 0],
				[0, 0, 0, 0],
				[4, 3, 2, 1],
				[0, 0, 0, 0],
			]
		],
		[
			// yellow, 2x2
			[
				//
				[0, 0, 0, 0],
				[0, 1, 2, 0],
				[0, 3, 4, 0],
				[0, 0, 0, 0]
			],
			[
				//
				[0, 0, 0, 0],
				[0, 3, 1, 0],
				[0, 4, 2, 0],
				[0, 0, 0, 0]
			],
			[
				//
				[0, 0, 0, 0],
				[0, 4, 3, 0],
				[0, 2, 1, 0],
				[0, 0, 0, 0],
			],
			[
				//
				[0, 0, 0, 0],
				[0, 2, 4, 0],
				[0, 1, 3, 0],
				[0, 0, 0, 0],
			],
		],
		[
			// red s
			[
				//
				[0, 0, 4, 0],
				[0, 2, 3, 0],
				[0, 1, 0, 0],
				[0, 0, 0, 0],
				[0, 0, 0, 0],
			],
			[
				//
				[0, 1, 2, 0],
				[0, 0, 3, 4],
				[0, 0, 0, 0],
				[0, 0, 0, 0],
			],
			[
				//
				[0, 0, 0, 1],
				[0, 0, 3, 2],
				[0, 0, 4, 0],
				[0, 0, 0, 0],
				[0, 0, 0, 0],
			],
			[
				//
				[0, 0, 0, 0],
				[0, 4, 3, 0],
				[0, 0, 2, 1],
				[0, 0, 0, 0],
			],
		],
		[
			// orange L
			[
				//
				[0, 0, 1, 0],
				[0, 0, 2, 0],
				[0, 4, 3, 0],
				[0, 0, 0, 0]
			],
			[
				//
				[0, 4, 0, 0],
				[0, 3, 2, 1],
				[0, 0, 0, 0],
				[0, 0, 0, 0]
			],
			[
				//
				[0, 0, 3, 4],
				[0, 0, 2, 0],
				[0, 0, 1, 0],
				[0, 0, 0, 0]
			],
			[
				//
				[0, 0, 0, 0],
				[0, 1, 2, 3],
				[0, 0, 0, 4],
				[0, 0, 0, 0]
			]
		],
		[
			// purple plus
			[
				//
				[0, 0, 4, 0],
				[0, 1, 3, 0],
				[0, 0, 2, 0],
				[0, 0, 0, 0]
			],
			[
				//
				[0, 0, 1, 0],
				[0, 2, 3, 4],
				[0, 0, 0, 0],
				[0, 0, 0, 0]
			],
			[
				//
				[0, 0, 2, 0],
				[0, 0, 3, 1],
				[0, 0, 4, 0],
				[0, 0, 0, 0]
			],
			[
				//
				[0, 0, 0, 0],
				[0, 4, 3, 2],
				[0, 0, 1, 0],
				[0, 0, 0, 0]
			]
		],
		[
			// green Z
			[
				//
				[0, 2, 0, 0],
				[0, 1, 4, 0],
				[0, 0, 3, 0],
				[0, 0, 0, 0],
			],
			[
				//
				[0, 0, 1, 2],
				[0, 3, 4, 0],
				[0, 0, 0, 0],
				[0, 0, 0, 0],
			],
			[
				//
				[0, 0, 3, 0],
				[0, 0, 4, 1],
				[0, 0, 0, 2],
				[0, 0, 0, 0],
			],
			[
				//
				[0, 0, 0, 0],
				[0, 0, 4, 3],
				[0, 2, 1, 0],
				[0, 0, 0, 0],
			],
		],
		[
			// blue J
			[
				//
				[0, 4, 3, 0],
				[0, 0, 2, 0],
				[0, 0, 1, 0],
				[0, 0, 0, 0]
			],
			[
				//
				[0, 0, 0, 4],
				[0, 1, 2, 3],
				[0, 0, 0, 0],
				[0, 0, 0, 0]
			],
			[
				//
				[0, 0, 1, 0],
				[0, 0, 2, 0],
				[0, 0, 3, 4],
				[0, 0, 0, 0]
			],
			[
				//
				[0, 0, 0, 0],
				[0, 3, 2, 1],
				[0, 4, 0, 0],
				[0, 0, 0, 0]
			]
		]
	];

	// not all silhouettes have the top left coordinate be in the tetromino - this is the first tile on the second row (all tiles have a piece in the second row)
	var origin_offsets = [
		// for each color, include all rotations
		[
			// cyan, LONG
			2,
			0,
			2,
			0
		],
		[
			// yellow, 2x2
			1,
			1,
			1,
			1
		],
		[
			// red s
			3,
			1,
			3,
			1
		],
		[
			// orange L
			2,
			1,
			2,
			1
		],
		[
			// purple plus
			2,
			1,
			1,
			1
		],
		[
			// green Z
			2,
			2,
			2,
			2
		],
		[
			// blue J
			2,
			1,
			2,
			1
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

	function newLevel() {}

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
				for (i in (-4)...gridwidth)
				{
					for (j in (-4)...gridheight)
					{
						var sample_position_x = i + 1;
						var sample_position_y = j + origin_offsets[shape_i][rot_i];

						// if the block is the same as the current block type for this silhouette
						if (sample_position_x >= 0
							&& sample_position_x < gridwidth
							&& sample_position_y >= 0
							&& sample_position_y < gridheight
							&& boardstate[sample_position_x][sample_position_y] == shape_i)
						{
							// check if the tetromino fits
							var match = true;
							for (k in 0...rot.length)
							{
								for (l in 0...rot[k].length)
								{
									if (rot[k][l] > 0)
									{
										if (i + k < 0 || j + l < 0 || i + k >= gridwidth || j + l >= gridheight || boardstate[i + k][j + l] != shape_i)
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
								gotten_forms[shape_i] = true;

								checkGameOver();
								trace("found shape " + shape_i + " w/ rotation " + rot_i + " at " + i + ", " + j);
								var pointInTetromino_x = i + 1;
								var pointInTetromino_y = j + origin_offsets[shape_i][rot_i];
								trace("tring to fill at " + pointInTetromino_x + ", " + pointInTetromino_y);
								var fillarea = findRegionSize(pointInTetromino_x, pointInTetromino_y);
								trace("fillarea " + fillarea);
								if (fillarea == 4)
								{
									for (k in 0...rot.length)
									{
										for (l in 0...rot[k].length)
										{
											if (rot[k][l] > 0)
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

		var removedcount = 0;
		// remove all found tetrominoes
		for (i in 0...gridwidth)
		{
			for (j in 0...gridheight)
			{
				if (foundmask[i * gridheight + j])
				{
					boardstate[i][j] = -1;
					removedcount++;
					trace("removing block at " + i + ", " + j);
					particles.x = playarea_x + (i) * tile_w + tile_w / 2;

					particles.y = playarea_y + (j) * tile_h + tile_h / 2;

					particles.emitParticle();
					particles.emitParticle();
					particles.emitParticle();
				}
			}
		}

		if (removedcount > 0)
		{
			FlxG.sound.play(AssetPaths.match2__mp3, 0.5);
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
		// for (i in 0...gridwidth)
		// {
		// 	if (boardstate[i][0] == -1)
		// 	{
		// 		boardstate[i][0] = Std.random(7);
		// 		anyPushed = true;
		// 	}
		// }
		return anyPushed;
	}

	private function solve(n:Int)
	{
		gotten_forms[n] = true;
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.R)
		{
			FlxG.resetState();
		}
		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.switchState(new Menu());
		}

		#if debug
		if (FlxG.keys.pressed.SHIFT)
		{
			if (FlxG.keys.justPressed.W)
			{
				checkGameOver(true);
			}
			if (FlxG.keys.justPressed.ONE)
			{
				solve(0);
			}
			if (FlxG.keys.justPressed.TWO)
			{
				solve(1);
			}
			if (FlxG.keys.justPressed.THREE)
			{
				solve(2);
			}
			if (FlxG.keys.justPressed.FOUR)
			{
				solve(3);
			}
			if (FlxG.keys.justPressed.FIVE)
			{
				solve(4);
			}
			if (FlxG.keys.justPressed.SIX)
			{
				solve(5);
			}
			if (FlxG.keys.justPressed.SEVEN)
			{
				solve(6);
			}
		}
		#end

		if (gameover)
		{
			return;
		}

		var dodrop:Bool = false;
		if (FlxG.keys.justPressed.S || FlxG.keys.justPressed.DOWN)
		{
			dodrop = true;
		}
		else if (FlxG.keys.pressed.S || FlxG.keys.pressed.DOWN)
		{
			dropPhase += elapsed;
			var thisdropinterval = Math.min(0.15, dropInterval);
			if (dropPhase >= thisdropinterval)
			{
				dropPhase -= thisdropinterval;
				dodrop = true;
			}
		}
		else
		{
			dropPhase += elapsed;
			if (dropPhase >= dropInterval)
			{
				dropPhase -= dropInterval;
				dodrop = true;
			}
			dodrop = false;
		}
		if (dodrop)
		{
			if (canFit(px, py + 1, p_rot))
			{
				py++;
			}
			else
			{
				placeBlock();
			}
		}

		if (FlxG.keys.justPressed.W || FlxG.keys.justPressed.UP)
		{
			moveBlock(0, 0, 1);
		}
		if (FlxG.keys.justPressed.A || FlxG.keys.justPressed.LEFT)
		{
			moveBlock(-1, 0, 0);
		}
		else if (FlxG.keys.pressed.A || FlxG.keys.pressed.LEFT)
		{
			leftPhase += elapsed;
			if (leftPhase >= 0.1)
			{
				leftPhase -= 0.1;
				moveBlock(-1, 0, 0);
			}
		}
		else
		{
			leftPhase = 0;
		}
		if (FlxG.keys.justPressed.D || FlxG.keys.justPressed.RIGHT)
		{
			moveBlock(1, 0, 0);
		}
		else if (FlxG.keys.pressed.D || FlxG.keys.pressed.RIGHT)
		{
			rightPhase += elapsed;
			if (rightPhase >= 0.1)
			{
				rightPhase -= 0.1;
				moveBlock(1, 0, 0);
			}
		}
		else
		{
			rightPhase = 0;
		}
		if (FlxG.keys.justPressed.SPACE || FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.X || FlxG.keys.justPressed.Q)
		{
			moveBlock(0, 0, 1);
		}
		if (FlxG.keys.justPressed.C || FlxG.keys.justPressed.E)
		{
			moveBlock(0, 0, -1);
		}
		applystate();
	}
}
