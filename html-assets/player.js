$(document).ready(function()
{
	// Player 1
	$("#play-btn-1").unbind('click');
	$("#play-btn-1").click(function()
	{
		$('#player_1')[0].play($('#play-1-url').val());
	});

	$("#stop-btn-1").unbind('click');
	$("#stop-btn-1").click(function()
	{
		$('#player_1')[0].stop();
	});

	$("#pause-btn-1").unbind('click');
	$("#pause-btn-1").click(function()
	{
		$('#player_1')[0].pause();
	});

	$("#resume-btn-1").unbind('click');
	$("#resume-btn-1").click(function()
	{
		$('#player_1')[0].resume();
	});


	// Player 2
	$("#play-btn-2").unbind('click');
	$("#play-btn-2").click(function()
	{
		$('#player_2')[0].play($('#play-1-url').val());
	});

	$("#stop-btn-2").unbind('click');
	$("#stop-btn-2").click(function()
	{
		$('#player_2')[0].stop();
	});

	$("#pause-btn-2").unbind('click');
	$("#pause-btn-2").click(function()
	{
		$('#player_2')[0].pause();
	});

	$("#resume-btn-2").unbind('click');
	$("#resume-btn-2").click(function()
	{
		$('#player_2')[0].resume();
	});
});