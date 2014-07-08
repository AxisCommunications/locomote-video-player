function streamStartedPlayer1()
{
	console.log("streamStarted player 1");
}

function streamStartedPlayer2()
{
	console.log("streamStarted player 2");
}

function streamStoppedPlayer1()
{
	console.log("streamStopped player 1");
}

function streamStoppedPlayer2()
{
	console.log("streamStopped player 2");
}

function streamPausedPlayer1()
{
	console.log("streamPaused player 1");
}

function streamPausedPlayer2()
{
	console.log("streamPaused player 2");
}

function streamResumedPlayer1()
{
	console.log("streamResumed player 1");
}

function streamResumedPlayer2()
{
	console.log("streamResumed player 2");
}


$(document).ready(function()
{
	var player1 = new locomote('player_1');
	var player2 = new locomote('player_2');

	player1.on("streamStarted", streamStartedPlayer1);
	player2.on("streamStarted", streamStartedPlayer2);
	//player1.off("streamStarted", streamStartedPlayer1);
	//player2.off("streamStarted", streamStartedPlayer2);
	player1.on("streamStopped", streamStoppedPlayer1);
	player2.on("streamStopped", streamStoppedPlayer2);
	player1.on("streamPaused", streamPausedPlayer1);
	player2.on("streamPaused", streamPausedPlayer2);
	player1.on("streamResumed", streamResumedPlayer1);
	player2.on("streamResumed", streamResumedPlayer2);

	// Player 1
	$("#play-btn-1").unbind('click');
	$("#play-btn-1").click(function()
	{
		player1.play($('#play-1-url').val());
	});

	$("#stop-btn-1").unbind('click');
	$("#stop-btn-1").click(function()
	{
		player1.stop();
	});

	$("#pause-btn-1").unbind('click');
	$("#pause-btn-1").click(function()
	{
		player1.pause();
	});

	$("#resume-btn-1").unbind('click');
	$("#resume-btn-1").click(function()
	{
		player1.resume();
	});


	// Player 2
	$("#play-btn-2").unbind('click');
	$("#play-btn-2").click(function()
	{
		player2.play($('#play-2-url').val());
	});

	$("#stop-btn-2").unbind('click');
	$("#stop-btn-2").click(function()
	{
		player2.stop();
	});

	$("#pause-btn-2").unbind('click');
	$("#pause-btn-2").click(function()
	{
		player2.pause();
	});

	$("#resume-btn-2").unbind('click');
	$("#resume-btn-2").click(function()
	{
		player2.resume();
	});
});