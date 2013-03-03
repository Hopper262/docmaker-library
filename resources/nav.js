function setpage(i) {
  $(location).attr('href', pages[i].url);
}

$(document).ready(function() {

  var geturl = function() {
    var rawurl = "" + $(location).attr('href');
    return rawurl.replace(/^.*\//, '');
  };
  
  var myurl = geturl();
  var myidx = 0;
  for (var i = 0; i < pages.length; i++) {
    if (pages[i].url == myurl)
      myidx = i;
  }  
  
  var cur_page_title = pages[myidx].title;
  
  var select_html = '';
  for (var i = 0; i < pages.length; i++) {
    select_html += '<li ';
    if (myidx == i)
      select_html += ' class="selected"';
    else
      select_html += ' onclick="setpage(' + i + ')"';
    select_html += '>' + pages[i].title + '</li>';
  }

  var desc_insert = desc_html;
  if (desc_insert != '')
    desc_insert += '<hr>';

  var headinfo = '<div id="indexTop"> ' +
'<img src="icon.png" class="icon aboutlauncher clickable" width="24" height="24"> ' +
'<h1 class="aboutlauncher clickable"> ' +
title +
'</h1> ' +
'<div class="pagenav"> ' +
'<div class="pageleft">&#x25C4;</div> ' +
'<div class="pageswitch"><div class="switchlabel">' +
cur_page_title +
'</div><ul>' +
select_html +
'</ul></div> ' +
'<div class="pageright">&#x25BA;</button> ' +
'</div> ' +
'</div> ' +
'<div id="aboutbox" style="display: none"> ' +
'<img src="icon.png" style="float: left; width: 32px; height: 32px; margin-left: 12px"> ' +
'<div style="margin: 0 24px 0 60px"> ' +
desc_insert +
'<p>This document was authored using <a href="http://systemfolder.wordpress.com/2010/03/25/mac-classics-docmaker/" target="_blank">DOCMaker</a>, created by Mark S. Wall, Green Mountain Software.</p> ' +
'<p>The document was converted to HTML using <a href="http://docmaker.whpress.com/" target="_blank">DOCMaker Library</a>, created by Jeremiah Morris, Weedhopper Press.</p> ' +
'<p>Download as: <a href="' + dm_archive + '">DOCMaker</a>, <a href="' +
ht_archive +
'">HTML</a></p>' +
'</div> ' +
'</div>';

    $('BODY').append(headinfo);
    $('BODY').addClass('withnav');
    
    var $menu = $('#indexTop .pageswitch UL');
    $menu.hide();
    $('#indexTop .pageswitch').hover(
      function() {
        $menu.fadeIn(300);
      },
      function() {
        $menu.fadeOut(300);
      }
      );      

    var $prev = $('#indexTop .pageleft');
    if (myidx == 0)
      $prev.css('opacity', 0.5);
    else {
      $prev.addClass('clickable');
      $prev.click(function() {
        setpage(myidx - 1);
        return false;
      });
    }
    
    var $next = $('#indexTop .pageright');
    if (myidx == (pages.length - 1))
      $next.css('opacity', 0.5);
    else {
      $next.addClass('clickable');
      $next.click(function() {
        setpage(myidx + 1);
        return false;
      });
    }

   var $aboutbox = $("#aboutbox").dialog({
      width: 440,
      modal: true,
      resizable: false,
      draggable: false,
      autoOpen: false,
      open: function() {
          $(this).find('a').blur();
        },
      });
    $(".aboutlauncher").click(function () {
      $aboutbox.dialog('open');
      return false;
      });
    
    
    });
