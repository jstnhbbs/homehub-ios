# Builds a hull whose bottom edge is the wave's top edge, lifted by a constant gap.
def bez(p, t):
    (x0,y0),(x1,y1),(x2,y2),(x3,y3) = p; u = 1-t
    return (u**3*x0+3*u*u*t*x1+3*u*t*t*x2+t**3*x3, u**3*y0+3*u*u*t*y1+3*u*t*t*y2+t**3*y3)
def split(p, t):
    def lerp(a,b): return (a[0]+(b[0]-a[0])*t, a[1]+(b[1]-a[1])*t)
    a,b,c,d = p; ab,bc,cd = lerp(a,b),lerp(b,c),lerp(c,d); abc,bcd = lerp(ab,bc),lerp(bc,cd); m = lerp(abc,bcd)
    return (a,ab,abc,m), (m,bcd,cd,d)
def t_at_x(p, x):
    lo, hi = 0.0, 1.0
    for _ in range(60):
        mid = (lo+hi)/2
        if bez(p, mid)[0] < x: lo = mid
        else: hi = mid
    return (lo+hi)/2
# the wave's upper edge (left to right): two segments, from WAVE in clean.py
W1 = ((82,756),(204,683),(324,687),(466,730))
W2 = ((466,730),(627,778),(792,783),(938,725))
def hull(gap, x_stern=150, x_bow=812):
    t1 = t_at_x(W1, x_stern); _, a = split(W1, t1)            # from the stern to the end of segment 1
    t2 = t_at_x(W2, x_bow);  b, _ = split(W2, t2)              # from the start of segment 2 to the bow
    up = lambda q: tuple((x, y-gap) for x, y in q)
    a, b = up(a), up(b)
    f = lambda q: f"{q[0]:.0f} {q[1]:.0f}"
    # bottom edge, drawn right to left: bow corner -> segment 2 reversed -> segment 1 reversed -> stern
    bow = b[3]; mid = b[0]; stern = a[3] if False else a[0]
    seg2_rev = f"C{f(b[2])} {f(b[1])} {f(b[0])}"
    seg1_rev = f"C{f(a[2])} {f(a[1])} {f(a[0])}"
    # right side: from the bow tip down to the bottom-right corner, then onto the bottom edge
    import math
    dx, dy = bow[0]-b[2][0], bow[1]-b[2][1]; n = math.hypot(dx, dy)
    k = 62                                            # how far the corner curve runs along the bottom edge's direction
    c2 = (bow[0] + dx/n*k, bow[1] + dy/n*k)
    path = (f"M150 575 C335 574 605 536 862 470 C894 462 916 478 913 511 "
            f"C909 590 {c2[0]:.0f} {c2[1]:.0f} {f(bow)} "
            f"{seg2_rev} {seg1_rev} "
            f"C{a[0][0]-10:.0f} {a[0][1]+4:.0f} {a[0][0]-20:.0f} {a[0][1]+2:.0f} {a[0][0]-24:.0f} {a[0][1]-12:.0f} "
            f"L117 607 C114 584 128 575 150 575 Z")
    return path
if __name__ == "__main__":
    import sys
    print(hull(float(sys.argv[1]) if len(sys.argv) > 1 else 36))
