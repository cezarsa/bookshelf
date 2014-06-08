(function($) {

    var scrollElement = $('html, body'),
        booksArea = $('.books'),
        books = booksArea.find('.book'),
        $window = $(window),
        scrollTimeout = null;

    var oldWidth = null, oldHeight = null;

    var update = function() {
        var winWidth = $window.width(),
            winHeight = $window.height();

        if (oldWidth === winWidth && oldHeight === winHeight) {
            return;
        }
        oldWidth = winWidth;
        oldHeight = winHeight;

        fixBooksArea(winWidth);
        startSideAnimation();
        startScrollAnimation(winHeight);
    };

    var fixBooksArea = function(width) {
        var toBreak = [],
            acc = 0,
            lastBreak = 0;

        booksArea.width(width);
        books.stop(true, false);
        booksArea.find('.book').appendTo(booksArea);
        booksArea.find('.line').remove();

        var line = $('<div class="line">'),
            lineWidth = 0;

        for (var i = 0, len = books.length; i < len; ++i) {
            var item = books.eq(i),
                pos = item.offset();

            lineWidth += item.width();
            line.append(item);

            if (lineWidth > width) {
                line.data('amount', lineWidth - width);
                booksArea.append(line);
                lineWidth = 0;
                line = $('<div class="line">');
            }
        }

        if (lineWidth > 0) {
            booksArea.append(line);
        }
    };

    var startSideAnimation = function() {
        booksArea.find('.line').each(function() {
            var el = $(this),
                duration = Math.max(1000, 40 * parseInt(el.data('amount'), 10));

            var doAnimation = function() {
                el.animate({
                    marginLeft: -el.data('amount')
                }, {
                    duration: duration,
                    complete: function() {
                        el.animate({ marginLeft: 0 }, {
                            duration: duration,
                            complete: function() {
                                setTimeout(doAnimation, 0);
                            }
                        });
                    }
                });
            };
            doAnimation();
        });
    }

    var startScrollAnimation = function(winHeight) {
        var amount = booksArea.height() - winHeight,
            duration = amount * 20;
        if (amount < 0) {
            return;
        }

        var doScrollAnimation = function() {
            var goingBack = false;
            scrollElement.animate({
                scrollTop: amount
            }, {
                easing: 'linear',
                duration: duration,
                complete: function() {
                    if (goingBack) {
                        return;
                    }
                    goingBack = true;
                    scrollElement.animate({ scrollTop: 0 }, {
                        easing: 'linear',
                        duration: duration,
                        complete: function() {
                            if (!goingBack) {
                                return;
                            }
                            goingBack = false;
                            scrollTimeout = setTimeout(doScrollAnimation, 0);
                        }
                    });
                }
            });
        };
        clearTimeout(scrollTimeout);
        scrollElement.stop(true, false).scrollTop(0);
        doScrollAnimation();
    };

    var toRGB = function(arr) {
        return "rgb(" + arr.join(',') + ")";
    };

    var updateLabelColors = function() {
        books.each(function(i, book) {
            book = $(book);
            var img = book.find('img'),
                src = img.attr('src');
            $.getJSON("http://localhost:5000/img/" + src, function(data) {
                book.data('colors', data);
                var data = book.data('colors'),
                    colors = data.colors;
                book.find('.side').css('background-color', toRGB(colors[0]));
                book.find('.title').css('color', toRGB(colors[1]));
                book.find('.author').css('color', toRGB(colors[2]));
            });
        });
    };

    $window.resize(update);
    $window.keyup(function (ev) {
        if (ev.keyCode === 27) {
            clearTimeout(scrollTimeout);
            scrollElement.stop(true, false);
        }
    });

    booksArea.on('mouseenter', '.book', function() {
        var el = $(this);
        el.addClass('three-d');
    });
    booksArea.on('mouseleave', '.book', function() {
        var el = $(this);
        el.removeClass('three-d');
    });

    booksArea.imagesLoaded(update);
    updateLabelColors();
}(jQuery));
