(function($) {

    var scrollElement = $('html, body'),
        booksArea = $('.books'),
        items = booksArea.find('.book'),
        $window = $(window),
        scrollTimeout = null;

    var oldWidth = null, oldHeight = null;
    var update = function(opts) {
        var winWidth = $window.width(),
            winHeight = $window.height();

        if (oldWidth === winWidth && oldHeight === winHeight) {
            return;
        }
        oldWidth = winWidth;
        oldHeight = winHeight;

        var width = winWidth,
            toBreak = [],
            acc = 0,
            lastBreak = 0;

        booksArea.width(width);
        items.stop(true, false);
        booksArea.find('.book').appendTo(booksArea);
        booksArea.find('.line').remove();

        var line = $('<div class="line">'),
            lineWidth = 0;

        for (var i = 0, len = items.length; i < len; ++i) {
            var item = items.eq(i),
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
}(jQuery));
