(function($) {

    var scrollElement = $('html, body'),
        booksArea = $('.books'),
        items = booksArea.find('> div'),
        $window = $(window);

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

        booksArea.width(width).find('br').remove();
        items.stop(true, false).css('margin-left', 0).removeClass('break');

        for (var i = 0, len = items.length; i < len; ++i) {
            var item = items.eq(i),
                pos = item.offset();
            item.data('amount', 0);
            if (i === len - 1) {
                if (pos.left + item.width() - acc > width) {
                    items.eq(lastBreak).data('amount', pos.left + item.width() - acc - width);
                }
            }
            if ((pos.left - acc) > width) {
                items.eq(lastBreak).data('amount', pos.left - acc - width);
                acc = pos.left;
                toBreak.push(i);
                lastBreak = i;
            }
        }

        for (i = 0; i < toBreak.length; ++i) {
            items.eq(toBreak[i]).addClass('break');
            items.eq(toBreak[i]).before('<br>');
        }

        items.eq(0).add('> div.break', booksArea).each(function() {
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
                            setTimeout(doScrollAnimation, 0);
                        }
                    });
                }
            });
        };
        // scrollElement.stop(true, false).scrollTop(0);
        // doScrollAnimation();

    };

    $window.resize(update);
    booksArea.imagesLoaded(update);
}(jQuery));
